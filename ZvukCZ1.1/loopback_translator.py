#!/usr/bin/env python3
"""
Systémový zvuk (WASAPI loopback) -> přepis (Whisper) -> překlad do češtiny.

Bere to, co hraje na výstupu zvukové karty, takže funguje na Mumble,
Discord, YouTube, cokoliv. Mluvčí ale nejsou oddělení - všechno přijde
smíchané dohromady.

Instalace (jen Windows):
    pip install PyAudioWPatch faster-whisper numpy scipy deepl

Spuštění:
    set DEEPL_KEY=...        # volitelné, bez klíče se jen přepisuje
    python loopback_translator.py
"""

import ctypes
import json
import os
import queue
import sysconfig
import threading
import time
import tkinter as tk
from tkinter import colorchooser
from tkinter import font as tkfont

for _pkg in ("cublas", "cudnn"):
    _bin = os.path.join(sysconfig.get_paths()["purelib"], "nvidia", _pkg, "bin")
    if os.path.isdir(_bin):
        os.add_dll_directory(_bin)
        os.environ["PATH"] = _bin + os.pathsep + os.environ["PATH"]

import keyboard
import numpy as np
import pyaudiowpatch as pyaudio
import pystray
from PIL import Image, ImageDraw
from scipy.signal import resample_poly
from faster_whisper import WhisperModel

# ---------------------------------------------------------------- nastavení

WHISPER_RATE = 16000
CHUNK = 1024

SILENCE_RMS = 0.004   # pod touto hlasitostí to beru jako ticho
SILENCE_GAP = 0.8     # s ticha = konec promluvy
MIN_SPEECH = 0.4      # kratší úseky zahodím
MAX_SPEECH = 15.0     # delší promluvu rozseknu

MODEL_SIZE = "small"  # tiny / base / small / medium / large-v3
DEVICE = "cuda"       # "cpu" pokud by GPU dělalo problémy
COMPUTE = "float16"   # na CPU spíš "int8"

work_queue: queue.Queue = queue.Queue()
overlay_queue: queue.Queue = queue.Queue()
command_queue: queue.Queue = queue.Queue()   # akce z tray ikonky / klávesových zkratek

running_event = threading.Event()   # vypnuto = poslech/přepis pozastaven (tray Start/Stop)
running_event.set()

SUBTITLE_SECONDS = 7.0   # jak dlouho titulek zůstane na obrazovce

SETTINGS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "overlay_settings.json")
DEFAULT_SETTINGS = {
    "opacity": 0.85,          # 0.1 - 1.0
    "font_size": 20,
    "text_color": "#ffffff",
    "max_width_ratio": 0.7,   # box se nerozšíří přes tuto část obrazovky
    "anchor_x": None,         # střed boxu na ose X; None = auto (střed obrazovky)
    "anchor_y": None,         # spodní hrana boxu na ose Y; None = auto (u spodku obrazovky)
    "hotkey_settings": "",    # např. "ctrl+alt+n" - prázdné = vypnuto
    "hotkey_move": "",        # např. "ctrl+alt+m" - prázdné = vypnuto
}


def load_settings():
    settings = dict(DEFAULT_SETTINGS)
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                settings.update(json.load(f))
        except Exception as exc:
            print(f"[nastavení overlaye se nepodařilo načíst: {exc}]")
    return settings


def save_settings(settings):
    try:
        with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
            json.dump(settings, f, ensure_ascii=False, indent=2)
    except Exception as exc:
        print(f"[nastavení overlaye se nepodařilo uložit: {exc}]")

# ---------------------------------------------------------------- překlad

_deepl = None
if os.getenv("DEEPL_KEY"):
    import deepl
    _deepl = deepl.Translator(os.environ["DEEPL_KEY"])


def to_czech(text: str) -> str:
    if not _deepl:
        return text
    try:
        return _deepl.translate_text(text, target_lang="CS").text
    except Exception as exc:
        print(f"[překlad selhal: {exc}]")
        return text


# ---------------------------------------------------------------- zdroj zvuku

def find_loopback(p):
    """Najde loopback zařízení odpovídající aktuálnímu výstupu."""
    wasapi = p.get_host_api_info_by_type(pyaudio.paWASAPI)
    speakers = p.get_device_info_by_index(wasapi["defaultOutputDevice"])

    if speakers.get("isLoopbackDevice"):
        return speakers

    for lb in p.get_loopback_device_info_generator():
        if speakers["name"] in lb["name"]:
            return lb

    raise RuntimeError(
        "Loopback zařízení nenalezeno. Zkontroluj, že máš ve Windows "
        "nastavený správný výstup zvuku."
    )


def capture():
    with pyaudio.PyAudio() as p:
        dev = find_loopback(p)
        rate = int(dev["defaultSampleRate"])
        channels = int(dev["maxInputChannels"])
        print(f"Poslouchám: {dev['name']}  ({rate} Hz, {channels} kanálů)\n")

        stream = p.open(
            format=pyaudio.paInt16,
            channels=channels,
            rate=rate,
            frames_per_buffer=CHUNK,
            input=True,
            input_device_index=dev["index"],
        )

        chunks = []
        last_sound = 0.0
        speaking = False

        def flush():
            nonlocal chunks, speaking
            if not chunks:
                return
            raw = b"".join(chunks)
            chunks = []
            speaking = False
            audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
            if channels > 1:
                audio = audio.reshape(-1, channels).mean(axis=1)
            if len(audio) / rate < MIN_SPEECH:
                return
            work_queue.put(resample_poly(audio, WHISPER_RATE, rate))

        while True:
            data = stream.read(CHUNK, exception_on_overflow=False)
            if not running_event.is_set():
                continue   # zvuk zahodíme, jen ať se nezaplní buffer (pauza z tray)
            block = np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768.0
            rms = float(np.sqrt(np.mean(block ** 2)))
            now = time.time()

            if rms > SILENCE_RMS:
                chunks.append(data)
                last_sound = now
                speaking = True
            elif speaking:
                chunks.append(data)   # krátké pauzy uvnitř věty si nechám
                if now - last_sound >= SILENCE_GAP:
                    flush()

            if speaking:
                dur = sum(len(c) for c in chunks) / 2 / channels / rate
                if dur >= MAX_SPEECH:
                    flush()


# ---------------------------------------------------------------- overlay (titulky přes hru)

class Overlay:
    """Poloprůhledné okno s titulky, vždy navrchu, klikatelné skrz (neblokuje hru).
    Velikost boxu se přizpůsobuje délce textu (krátká věta = úzký box).
    Ovládá se přes ikonku v system tray (nastavení, přesun, pauza, konec),
    volitelně i přes klávesové zkratky."""

    TRANSPARENT_KEY = "#000000"  # tato barva zmizí (klíčovací barva), box má jinou
    BOTTOM_MARGIN = 100          # výchozí mezera mezi spodkem boxu a spodkem obrazovky
    PAD_X = 20
    PAD_Y = 10

    def __init__(self):
        self.settings = load_settings()
        self.current_text = " "
        self.settings_panel = None
        self.move_mode = False
        self.tray_icon = None
        self.hk_settings_entry = None
        self.hk_move_entry = None
        self._clear_job = None

        self.root = tk.Tk()
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg=self.TRANSPARENT_KEY)
        self.root.attributes("-transparentcolor", self.TRANSPARENT_KEY)

        self.screen_w = self.root.winfo_screenwidth()
        self.screen_h = self.root.winfo_screenheight()
        self.max_width = int(self.screen_w * self.settings["max_width_ratio"])
        self.font = tkfont.Font(family="Segoe UI", size=self.settings["font_size"], weight="bold")

        self.label = tk.Label(
            self.root,
            text="",
            fg=self.settings["text_color"],
            bg="#111111",
            font=self.font,
            justify="center",
            highlightthickness=3,
            highlightbackground="#111111",  # v běžném stavu splyne s pozadím boxu
        )
        self.label.pack(padx=self.PAD_X, pady=self.PAD_Y)

        self._resize(" ")
        self._set_clickthrough(True)
        self._start_tray()
        self._register_hotkeys()
        self._poll()

    # ------------------------------------------------------------ vzhled/pozice

    def _effective_anchor(self):
        cx = self.settings["anchor_x"]
        by = self.settings["anchor_y"]
        if cx is None:
            cx = self.screen_w // 2
        if by is None:
            by = self.screen_h - self.BOTTOM_MARGIN
        return cx, by

    def _resize(self, text):
        """Nastaví text a přizpůsobí velikost/pozici okna, aby box těsně obepínal obsah."""
        self.current_text = text
        max_text_width = self.max_width - 2 * self.PAD_X
        self.label.config(wraplength=max_text_width, text=text)
        self.root.update_idletasks()
        # reqwidth/reqheight uz zahrnuji i highlightthickness (barevny okraj pro rezim presunu)
        box_width = max(self.label.winfo_reqwidth() + 2 * self.PAD_X, 40)
        box_height = self.label.winfo_reqheight() + 2 * self.PAD_Y

        cx, bottom_y = self._effective_anchor()
        x = cx - box_width // 2
        y = bottom_y - box_height
        self.root.geometry(f"{box_width}x{box_height}+{x}+{y}")
        self.root.update_idletasks()

    def _set_clickthrough(self, enabled):
        """enabled=True: normální stav (klikatelné skrz i průhledné, hra dostane klik).
        enabled=False: režim přesunu - box lze chytit a táhnout myší.

        Nestačí přepínat jen WS_EX_TRANSPARENT - samotné WS_EX_LAYERED rozbíjí
        hit-testing (WindowFromPoint/klik "vidí" okno pod námi, i když
        GetWindowLongW správně hlásí, že WS_EX_TRANSPARENT je pryč). Proto se
        v režimu přesunu WS_EX_LAYERED úplně odebere (okno přestane být
        průhledné/klikatelné-skrz úplně, což nevadí - _enter_move_mode zároveň
        zneprůhlední i barvu pozadí, takže o nic vizuálně nepřijdeme).
        """
        GWL_EXSTYLE = -20
        WS_EX_LAYERED = 0x00080000
        WS_EX_TRANSPARENT = 0x00000020
        LWA_COLORKEY = 0x00000001
        LWA_ALPHA = 0x00000002
        SWP_NOMOVE = 0x0002
        SWP_NOSIZE = 0x0001
        SWP_NOZORDER = 0x0004
        SWP_NOACTIVATE = 0x0010
        SWP_FRAMECHANGED = 0x0020

        hwnd = self.root.winfo_id()
        style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
        if enabled:
            style |= WS_EX_LAYERED | WS_EX_TRANSPARENT
        else:
            style &= ~(WS_EX_LAYERED | WS_EX_TRANSPARENT)
        ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style)
        ctypes.windll.user32.SetWindowPos(
            hwnd, 0, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED,
        )
        if enabled:
            # SetWindowLongW zapomene puvodni nastaveni, je potreba je znovu poslat,
            # jinak okno zcerna. LWA_ALPHA navic drzi celkovou pruhlednost boxu.
            alpha = int(self.settings["opacity"] * 255)
            ctypes.windll.user32.SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_COLORKEY | LWA_ALPHA)

    # ------------------------------------------------------------ režim přesunu (tažení myší)

    def _enter_move_mode(self):
        self.move_mode = True
        # barva pozadí okna (odsazení okolo boxu) jinak splývá s klíčovací barvou
        # a tedy je klikatelná-skrz NEZÁVISLE na WS_EX_TRANSPARENT - v režimu
        # přesunu proto celé okno zneprůhledníme, aby tažení nic nerušilo.
        self.root.configure(bg="#111111")
        self.label.config(highlightbackground="#3399ff")  # modrý okraj = jsi v editačním režimu
        # navázáno na root i label, ať jde chytit i za odsazení kolem textu, ne jen za text samotný
        for widget in (self.root, self.label):
            widget.bind("<ButtonPress-1>", self._on_box_press)
            widget.bind("<B1-Motion>", self._on_box_drag)
            widget.bind("<ButtonRelease-1>", self._on_box_release)
        self._refresh_tray()
        # POZOR na pořadí: configure(bg=...) při aktivním -transparentcolor může
        # uvnitř Tk znovu nastavit WS_EX_TRANSPARENT, proto jde _set_clickthrough
        # jako úplně poslední krok.
        self._set_clickthrough(False)

    def _exit_move_mode(self):
        self.move_mode = False
        self._set_clickthrough(True)
        self.root.configure(bg=self.TRANSPARENT_KEY)
        self.label.config(highlightbackground="#111111")
        for widget in (self.root, self.label):
            widget.unbind("<ButtonPress-1>")
            widget.unbind("<B1-Motion>")
            widget.unbind("<ButtonRelease-1>")
        save_settings(self.settings)
        self._refresh_tray()

    def _toggle_move_mode(self):
        if self.move_mode:
            self._exit_move_mode()
        else:
            self._enter_move_mode()

    def _on_box_press(self, event):
        print(f"DEBUG press {event.x_root},{event.y_root}")
        self._drag_start = (event.x_root, event.y_root)
        self._drag_anchor_start = self._effective_anchor()

    def _on_box_drag(self, event):
        print(f"DEBUG drag {event.x_root},{event.y_root}")
        dx = event.x_root - self._drag_start[0]
        dy = event.y_root - self._drag_start[1]
        cx0, by0 = self._drag_anchor_start
        self.settings["anchor_x"] = cx0 + dx
        self.settings["anchor_y"] = by0 + dy
        self._resize(self.current_text)

    def _on_box_release(self, _event):
        print("DEBUG release")
        save_settings(self.settings)

    # ------------------------------------------------------------ panel nastavení

    def _toggle_settings_panel(self):
        if self.settings_panel is not None and self.settings_panel.winfo_exists():
            self.settings_panel.destroy()
            self.settings_panel = None
            self.hk_settings_entry = None
            self.hk_move_entry = None
            return

        panel = tk.Toplevel(self.root)
        panel.title("ZvukCZ – nastavení titulků")
        panel.attributes("-topmost", True)
        panel.resizable(False, False)
        self.settings_panel = panel

        # pozn.: tk.Scale umi po .set()/preskladani sveho okna sam znovu zavolat
        # command se stejnou hodnotou (zpetnovazebni smycka pres update_idletasks
        # v _resize) - proto se tu reaguje jen na skutecnou zmenu hodnoty.

        def on_opacity(val):
            new_opacity = int(float(val)) / 100
            if new_opacity == self.settings["opacity"]:
                return
            self.settings["opacity"] = new_opacity
            self._set_clickthrough(not self.move_mode)
            save_settings(self.settings)

        def on_font_size(val):
            new_size = int(float(val))
            if new_size == self.settings["font_size"]:
                return
            self.settings["font_size"] = new_size
            self.font.configure(size=new_size)
            self._resize(self.current_text)
            save_settings(self.settings)

        def on_width(val):
            new_ratio = int(float(val)) / 100
            if new_ratio == self.settings["max_width_ratio"]:
                return
            self.settings["max_width_ratio"] = new_ratio
            self.max_width = int(self.screen_w * new_ratio)
            self._resize(self.current_text)
            save_settings(self.settings)

        def pick_color():
            _, hexval = colorchooser.askcolor(
                color=self.settings["text_color"], title="Barva textu", parent=panel
            )
            if hexval:
                self.settings["text_color"] = hexval
                self.label.config(fg=hexval)
                color_btn.config(bg=hexval)
                save_settings(self.settings)

        def reset_position():
            self.settings["anchor_x"] = None
            self.settings["anchor_y"] = None
            self._resize(self.current_text)
            save_settings(self.settings)

        tk.Label(panel, text="Průhlednost").pack(anchor="w", padx=10, pady=(10, 0))
        op_scale = tk.Scale(panel, from_=10, to=100, orient="horizontal", length=220, command=on_opacity)
        op_scale.set(int(self.settings["opacity"] * 100))
        op_scale.pack(padx=10)

        tk.Label(panel, text="Velikost textu").pack(anchor="w", padx=10, pady=(10, 0))
        size_scale = tk.Scale(panel, from_=12, to=40, orient="horizontal", length=220, command=on_font_size)
        size_scale.set(self.settings["font_size"])
        size_scale.pack(padx=10)

        tk.Label(panel, text="Max. šířka (% obrazovky)").pack(anchor="w", padx=10, pady=(10, 0))
        width_scale = tk.Scale(panel, from_=20, to=95, orient="horizontal", length=220, command=on_width)
        width_scale.set(int(self.settings["max_width_ratio"] * 100))
        width_scale.pack(padx=10)

        color_btn = tk.Button(panel, text="Barva textu...", bg=self.settings["text_color"], command=pick_color)
        color_btn.pack(padx=10, pady=10, fill="x")

        tk.Button(panel, text="Resetovat pozici", command=reset_position).pack(padx=10, pady=(0, 10), fill="x")

        def apply_hotkeys():
            self.settings["hotkey_settings"] = self.hk_settings_entry.get().strip()
            self.settings["hotkey_move"] = self.hk_move_entry.get().strip()
            self._register_hotkeys()
            save_settings(self.settings)

        tk.Label(panel, text="Klávesová zkratka – Nastavení (napiš, nebo nahraj)").pack(
            anchor="w", padx=10, pady=(10, 0)
        )
        row1 = tk.Frame(panel)
        row1.pack(padx=10, fill="x")
        self.hk_settings_entry = tk.Entry(row1, width=20)
        self.hk_settings_entry.insert(0, self.settings.get("hotkey_settings", ""))
        self.hk_settings_entry.pack(side="left", fill="x", expand=True)
        tk.Button(row1, text="Nahrát...", command=lambda: self._record_hotkey("settings")).pack(
            side="left", padx=(6, 0)
        )

        tk.Label(panel, text="Klávesová zkratka – Přesun (napiš, nebo nahraj)").pack(
            anchor="w", padx=10, pady=(10, 0)
        )
        row2 = tk.Frame(panel)
        row2.pack(padx=10, fill="x")
        self.hk_move_entry = tk.Entry(row2, width=20)
        self.hk_move_entry.insert(0, self.settings.get("hotkey_move", ""))
        self.hk_move_entry.pack(side="left", fill="x", expand=True)
        tk.Button(row2, text="Nahrát...", command=lambda: self._record_hotkey("move")).pack(
            side="left", padx=(6, 0)
        )

        tk.Button(panel, text="Uložit zkratky", command=apply_hotkeys).pack(padx=10, pady=10, fill="x")

        def on_close():
            self.settings_panel = None
            self.hk_settings_entry = None
            self.hk_move_entry = None
            panel.destroy()

        panel.protocol("WM_DELETE_WINDOW", on_close)

    # ------------------------------------------------------------ system tray

    @staticmethod
    def _make_tray_image(active=True):
        """Malý titulkový box s "CZ" (stejný styl jako overlay). Když je poslech
        pozastavený (Stop), přidá se červené přeškrtnutí."""
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        box = (3, 18, 61, 46)
        d.rounded_rectangle(box, radius=8, fill=(17, 17, 17, 255), outline=(51, 153, 255, 255), width=3)

        try:
            from PIL import ImageFont
            font = ImageFont.truetype("arialbd.ttf", 20)
        except Exception:
            font = None
        text = "CZ"
        bbox = d.textbbox((0, 0), text, font=font) if font else d.textbbox((0, 0), text)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        tx = (64 - tw) / 2 - bbox[0]
        ty = box[1] + (box[3] - box[1] - th) / 2 - bbox[1]
        d.text((tx, ty), text, font=font, fill="white")

        if not active:
            d.line((8, 8, 56, 56), fill=(230, 40, 40, 255), width=6)
        return img

    def _start_tray(self):
        def running_text(_item):
            return "Stop" if running_event.is_set() else "Start"

        def move_text(_item):
            return "Dokončit přesun" if self.move_mode else "Posunout titulky"

        def tooltip_text():
            stav = "běží" if running_event.is_set() else "pozastaveno"
            return f"ZvukCZ – {stav}"

        menu = pystray.Menu(
            pystray.MenuItem(running_text, lambda icon, item: command_queue.put("toggle_running")),
            pystray.MenuItem(move_text, lambda icon, item: command_queue.put("toggle_move")),
            pystray.MenuItem("Nastavení...", lambda icon, item: command_queue.put("settings")),
            pystray.MenuItem("Resetovat pozici", lambda icon, item: command_queue.put("reset_position")),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Ukončit", lambda icon, item: command_queue.put("quit")),
        )
        self.tray_icon = pystray.Icon(
            "zvukcz", self._make_tray_image(active=running_event.is_set()), tooltip_text(), menu
        )
        threading.Thread(target=self.tray_icon.run, daemon=True).start()

    def _refresh_tray(self):
        if self.tray_icon:
            try:
                self.tray_icon.icon = self._make_tray_image(active=running_event.is_set())
                self.tray_icon.title = (
                    f"ZvukCZ – {'běží' if running_event.is_set() else 'pozastaveno'}"
                )
                self.tray_icon.update_menu()
            except Exception:
                pass

    # ------------------------------------------------------------ klávesové zkratky

    def _record_hotkey(self, which):
        entry = self.hk_settings_entry if which == "settings" else self.hk_move_entry
        entry.config(state="normal")
        entry.delete(0, tk.END)
        entry.insert(0, "Stiskni klávesy...")
        entry.config(state="disabled")

        def worker():
            combo = keyboard.read_hotkey(suppress=False)
            command_queue.put(("hotkey_captured", which, combo))

        threading.Thread(target=worker, daemon=True).start()

    def _register_hotkeys(self):
        try:
            keyboard.unhook_all_hotkeys()
        except Exception:
            pass
        if self.settings.get("hotkey_settings"):
            try:
                keyboard.add_hotkey(self.settings["hotkey_settings"], lambda: command_queue.put("settings"))
            except Exception as exc:
                print(f"[zkratka pro nastavení se nepodařila zaregistrovat: {exc}]")
        if self.settings.get("hotkey_move"):
            try:
                keyboard.add_hotkey(self.settings["hotkey_move"], lambda: command_queue.put("toggle_move"))
            except Exception as exc:
                print(f"[zkratka pro přesun se nepodařila zaregistrovat: {exc}]")

    # ------------------------------------------------------------ ukončení

    def _quit(self):
        try:
            keyboard.unhook_all_hotkeys()
        except Exception:
            pass
        if self.tray_icon:
            try:
                self.tray_icon.stop()
            except Exception:
                pass
        self.root.destroy()

    # ------------------------------------------------------------ hlavní smyčka

    def _poll(self):
        try:
            while True:
                text = overlay_queue.get_nowait()
                self._resize(text)
                if self._clear_job:
                    self.root.after_cancel(self._clear_job)
                self._clear_job = self.root.after(
                    int(SUBTITLE_SECONDS * 1000), lambda: self._resize(" ")
                )
        except queue.Empty:
            pass

        try:
            while True:
                cmd = command_queue.get_nowait()
                if isinstance(cmd, tuple) and cmd[0] == "hotkey_captured":
                    _, which, combo = cmd
                    entry = self.hk_settings_entry if which == "settings" else self.hk_move_entry
                    try:
                        if entry is not None and entry.winfo_exists():
                            entry.config(state="normal")
                            entry.delete(0, tk.END)
                            entry.insert(0, combo)
                    except tk.TclError:
                        pass
                    continue
                if cmd == "settings":
                    self._toggle_settings_panel()
                elif cmd == "toggle_move":
                    self._toggle_move_mode()
                elif cmd == "toggle_running":
                    if running_event.is_set():
                        running_event.clear()
                    else:
                        running_event.set()
                    self._refresh_tray()
                elif cmd == "reset_position":
                    self.settings["anchor_x"] = None
                    self.settings["anchor_y"] = None
                    self._resize(self.current_text)
                    save_settings(self.settings)
                elif cmd == "quit":
                    self._quit()
                    return
        except queue.Empty:
            pass

        self.root.after(100, self._poll)

    def run(self):
        self.root.mainloop()


# ---------------------------------------------------------------- přepis

def transcriber():
    model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE)
    print("Model načten.\n")

    while True:
        audio = work_queue.get()
        try:
            segments, _ = model.transcribe(
                audio,
                language="en",
                vad_filter=True,
                beam_size=1,
                condition_on_previous_text=False,
            )
            text = " ".join(s.text.strip() for s in segments).strip()
            if not text:
                continue
            translated = to_czech(text)
            print(f"EN: {text}")
            print(f"CZ: {translated}\n")
            overlay_queue.put(translated)
        except Exception as exc:
            print(f"[chyba přepisu: {exc}]")
        finally:
            work_queue.task_done()


if __name__ == "__main__":
    threading.Thread(target=transcriber, daemon=True).start()
    threading.Thread(target=capture, daemon=True).start()
    Overlay().run()

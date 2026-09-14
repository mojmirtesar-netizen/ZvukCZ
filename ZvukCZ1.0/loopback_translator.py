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

import os
import queue
import sysconfig
import threading
import time

for _pkg in ("cublas", "cudnn"):
    _bin = os.path.join(sysconfig.get_paths()["purelib"], "nvidia", _pkg, "bin")
    if os.path.isdir(_bin):
        os.add_dll_directory(_bin)
        os.environ["PATH"] = _bin + os.pathsep + os.environ["PATH"]

import numpy as np
import pyaudiowpatch as pyaudio
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
            print(f"EN: {text}")
            print(f"CZ: {to_czech(text)}\n")
        except Exception as exc:
            print(f"[chyba přepisu: {exc}]")
        finally:
            work_queue.task_done()


if __name__ == "__main__":
    threading.Thread(target=transcriber, daemon=True).start()
    try:
        capture()
    except KeyboardInterrupt:
        print("\nKonec.")

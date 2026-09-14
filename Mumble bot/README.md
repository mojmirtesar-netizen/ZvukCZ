# Mumble bot – ZvukCZ pro Mumble

Bot, který se připojí přímo na Mumble server jako klient a překládá řeč
jednotlivých mluvčích zvlášť (na rozdíl od ZvukCZ, který poslouchá systémový
zvuk a mluvčí jsou smíchaní dohromady).

Překlad se zobrazuje na stejném typu overlaye jako ZvukCZ1.1 (poloprůhledný
box s titulky, klikatelný skrz, ovládání přes ikonku v system tray).

## Instalace

Vlastní virtuální prostředí (odděleně od ZvukCZ kvůli konfliktu verzí `protobuf`):

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Vygenerovat certifikát bota (jednou, pokud `bot_cert.pem`/`bot_key.pem` neexistují):

```powershell
openssl req -x509 -newkey rsa:2048 -keyout bot_key.pem -out bot_cert.pem -days 3650 -nodes -subj "/CN=ZvukCZ-Bot"
```

DeepL klíč: `deepl_key.txt` (stejný formát jako u ZvukCZ, do gitu nepatří).

## Spuštění

```powershell
.venv\Scripts\python.exe mumble_bot.py
```

Připojovací údaje k Mumble serveru (host/port/heslo/přezdívka) jsou zatím
natvrdo v hlavičce `mumble_bot.py` (`MUMBLE_HOST` atd.) – při přechodu na
jiný server je potřeba je tam upravit.

## Technické poznámky

- Knihovna `pymumble` (PyPI název, GitHub větev `pymumble_py3`) není aktivně
  udržovaná – autor hledá nového maintainera. Fungovala i tak.
- `opuslib` potřebuje nativní `opus.dll`, kterou dodává balíček `PyOgg`
  (cesta se přidává do `PATH` za běhu, stejný trik jako u cuBLAS/cuDNN).
- `pymumble` používá zastaralé `ssl.wrap_socket()`, odstraněné v Pythonu 3.12+
  – v `mumble_bot.py` je kompatibilní náhrada přes `ssl.SSLContext`.
- Audio z Mumble chodí dekódované jako 16-bit PCM mono, 48000 Hz, cca 20ms
  rámce, oddělené po jednotlivých uživatelích (`on_sound(user, chunk)`).

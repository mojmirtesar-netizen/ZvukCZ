# ZvukCZ

Aplikace zachytává systémový zvuk (WASAPI loopback), anglickou řeč přepisuje
pomocí Whisper (GPU/CUDA) a přeloženou češtinu zobrazuje jako poloprůhledné
titulky přes obrazovku (klikatelné skrz, nepřekáží ve hře).

## Instalace

1. Spusť `install.bat` (nebo `dist\ZvukCZ_Install.exe`, pokud instaluješ na
   jiný počítač bez tohoto zdrojového adresáře).
2. Instalátor ověří NVIDIA GPU, doinstaluje Python a potřebné balíčky.
3. Na konci se zeptá na DeepL API klíč – viz níže.
4. Po instalaci přes `.exe` přibude zástupce `ZvukCZ` na ploše.

## Získání DeepL API klíče (zdarma)

Bez klíče appka funguje jen jako přepis angličtiny (bez překladu do češtiny).
S klíčem přidá i překlad.

1. Jdi na **https://www.deepl.com/pro-api** a zaregistruj se do plánu
   **DeepL API Free** (kreditní karta se u free plánu obvykle vyžaduje kvůli
   ověření, ale nic se neúčtuje, dokud sám nepřejdeš na placený tarif).
   Free tier: 500 000 přeložených znaků měsíčně zdarma.
2. Po registraci najdeš svůj API klíč v účtu na
   **https://www.deepl.com/your-account/summary** (končí na `:fx`).
3. Klíč buď zadej přímo během instalace (`install.bat`/`ZvukCZ_Install.exe`
   se na něj zeptá), nebo ho kdykoliv později vlož do souboru
   `deepl_key.txt` v instalační složce (čistý text, jen samotný klíč,
   žádné uvozovky).

**Pozor:** `deepl_key.txt` obsahuje osobní klíč – nikam ho nesdílej ani
nekopíruj mimo svůj počítač (soubor je záměrně v `.gitignore`).

## Spuštění / zastavení / odinstalace

- `start.bat` – spustí appku na pozadí (bez viditelného okna, jen titulky).
- `stop.bat` – appku ukončí.
- `uninstall.bat` – appku zastaví, smaže zástupce z plochy a celou instalační
  složku (po potvrzení textem "ano").
- Po instalaci přes `.exe` lze appku spouštět i přes zástupce `ZvukCZ` na
  ploše.

## Ovládání za běhu

- Ikonka v system tray (u hodin) → pravé tlačítko:
  - **Start/Stop** – pozastaví/obnoví poslech (appka zůstává běžet).
  - **Posunout titulky** – přetažení titulkového boxu myší na jiné místo.
  - **Nastavení...** – zaškrtávátka **Zobrazit: Titulky / Historie**
    (např. jen historie bez titulků, nebo naopak), průhlednost, velikost a
    barva textu, max. šířka, citlivost na ticho a délka promluv
    (rozpoznávání řeči). Otevřená historie se po restartu appky otevře znovu.
  - **Historie překladů...** – poloprůhledný overlay nad hrou se všemi
    překlady (EN + CZ) od spuštění appky, kdyby titulek zmizel dřív, než ho
    stihneš přečíst. Scroluje se kolečkem myši, přesouvá tažením za horní
    lištu, velikost se mění úchytem vpravo dole. Klik do něj hře nebere
    klávesnici. Schovat/ukázat jde i klávesovou zkratkou (nastavíš v
    Nastavení), průhlednost má vlastní posuvník tamtéž. Totéž se průběžně
    ukládá do `historie_prekladu.txt` ve složce appky (tlačítko „soubor“);
    soubor se při každém spuštění appky přepíše.
  - **Resetovat pozici**.
  - **Ukončit**.
- Klávesové zkratky pro Nastavení/Posun/Historii se dají nastavit v panelu
  Nastavení (ruční zápis nebo tlačítko "Nahrát...").

Všechna nastavení se ukládají do `overlay_settings.json` a přežijí restart.

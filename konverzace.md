# Záznam konverzace – Mumble do CZ (loopback_translator.py)

Datum: 2026-09-13

## 1. Instalace Pythonu
Požadavek: stáhnout a nainstalovat Python, ale ne z Microsoft Storu.

- Zjištěno, že `python.exe` ve WindowsApps byl jen stub přesměrovávající do MS Storu – reálně Python nainstalovaný nebyl.
- Nainstalováno přes `winget install --id Python.Python.3.13 -e --source winget` (oficiální instalátor z python.org, staženo přes winget, ne přes msstore zdroj).
- Ověřeno: Python 3.13.15, pip 26.2.1.

## 2. Kontrola místa na disku
Požadavek: zkontrolovat volné místo (instalace ~2,5 GB).

- C: 174 GB volných, D: 151 GB, E: 579 GB, F: 899 GB – vše v pořádku.

## 3. Virtuální prostředí
Požadavek: vytvořit a aktivovat venv.

- Vytvořeno `.venv` ve složce projektu (`python -m venv .venv`).
- Aktivace ověřena (`VIRTUAL_ENV` nastaven, `python --version` uvnitř venv = 3.13.15).
- Poznámka: aktivace v mém PowerShell nástroji nepřetrvává mezi jednotlivými příkazy (každý běží jako nový proces) – uživatel musí aktivovat ve svém vlastním terminálu.

## 4. Instalace balíčků
Požadavek: nainstalovat PyAudioWPatch, faster-whisper, numpy, scipy, deepl.

- Vše nainstalováno bez chyb do `.venv`:
  PyAudioWPatch 0.2.12.8, faster-whisper 1.2.1, numpy 2.5.3, scipy 1.18.1, deepl 1.32.0
  (+ závislosti: ctranslate2, onnxruntime, tokenizers, huggingface-hub, av, …)

## 5. Test spuštění skriptu (nalezení zařízení + načtení modelu)
Požadavek: spustit skript, ověřit nalezení loopback zařízení a načtení modelu; nic neupravovat v logice ani SILENCE_RMS/SILENCE_GAP bez ptaní.

Skript: `loopback_translator.py` (systémový zvuk přes WASAPI loopback → Whisper přepis → DeepL překlad do CZ).

Narazili jsme na dva čistě environmentální problémy (skript samotný beze změny):

1. **`hf_xet` stahování modelu zamrzlo** (rychlý transfer protokol Hugging Face, na Windows umí viset bez chyby, 0 B staženo několik minut). Řešeno proměnnou prostředí `HF_HUB_DISABLE_XET=1`, která donutí `huggingface_hub` stahovat klasicky přes HTTP.
2. **Výstup skriptu se nezobrazoval** – `print()` do přesměrovaného (non-TTY) výstupu se v Pythonu bufferuje. Řešeno spuštěním s `-u` (nevyrovnávaný výstup) / `PYTHONUNBUFFERED=1`. Pro běžné spuštění v interaktivním terminálu uživatele se to netýká.

Výsledek ověření:
```
Poslouchám: VX2718-2KPC (NVIDIA High Definition Audio) [Loopback]  (48000 Hz, 2 kanálů)
Model načten.
```
Model: `small`, CPU, `int8`.

## 6. Nastavení DEEPL_KEY a živý test překladu
Požadavek: nastavit DEEPL_KEY a zkusit přeložit něco živě.

- Uživatel poskytl DeepL API klíč (free tier, format `...:fx`). Klíč byl ověřen samostatným testem DeepL API (`translate_text` + `get_usage`) – fungoval, 0/1 000 000 znaků využito.
- Skript spuštěn naživo s `DEEPL_KEY` nastaveným, uživatel pouštěl anglické mluvené audio (patrně vesmírná hra typu Elite Dangerous).

Ukázka reálného výstupu (přepis proběhl úspěšně, překlad dává smysl):
```
EN: I haven't been scanned yet. There is a silent scanner too. There we go. Yep, just got scanned.
CZ: Ještě mě neproskenovali. Je tu i tichý skener. A je to. Jo, právě mě proskenovali.

EN: As we got scanned we're gonna do a cool down Instant dock doesn't work for freighters...
CZ: Jakmile nás zachytí, musíme se schovat. Funkce „Instant dock" u nákladních lodí nefunguje...

EN: quiet, just one ship, one crew, one messy frontier plan. Then every tap turns into another decision...
CZ: Klid, jen jedna loď, jedna posádka, jeden chaotický plán pro průzkum hranic...
```

Testy probíhaly opakovaně (spuštění/zastavení na pozadí přes background tasky), pokaždé funkčně.

## 7. Skript nikam neloguje výsledky
Zjištěno na dotaz uživatele "kde najdu výsledek?": skript pouze vypisuje `EN:`/`CZ:` na konzoli, nikam to neukládá do souboru. Nabídnuto (zatím neprovedeno – vyžaduje úpravu logiky skriptu): přidat logování do `.txt`/`.csv` s časovými razítky, pokud o to uživatel požádá.

## 8. Test "v realu" ve vlastním terminálu
Uživatel chtěl spustit skript sám ve svém terminálu místo přes moje pozadí.

- Problém: `.venv\Scripts\Activate.ps1` nešlo spustit – PowerShell execution policy (`Restricted`) blokuje spouštění `.ps1` skriptů (výchozí bezpečnostní nastavení Windows).
- Nabídnuty dvě možnosti:
  - **A)** Nepoužívat aktivaci, volat přímo `.venv\Scripts\python.exe loopback_translator.py`.
  - **B)** Trvale povolit skripty: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`.
- Uživatel se zatím nerozhodl / požádal rovnou o uložení spouštěcího skriptu.

## 9. Spouštěcí skript `run.ps1`
Vytvořen `run.ps1` ve složce projektu, který nastaví `HF_HUB_DISABLE_XET=1` a `DEEPL_KEY` a rovnou zavolá `.venv\Scripts\python.exe loopback_translator.py` – obchází execution policy problém (nepotřebuje `Activate.ps1`) a odpadá nutnost pokaždé přepisovat DeepL klíč.

Spuštění:
```powershell
powershell -ExecutionPolicy Bypass -File .\run.ps1
```

**Bezpečnostní poznámka:** DeepL API klíč je v `run.ps1` uložen jako čistý text (zamaskováno i v tomto zápisu konverzace). Složka není git repozitář, ale klíč je čitelný komukoliv s přístupem k souboru. Pokud se bude skript sdílet nebo dostane pod git, klíč je potřeba přesunout mimo verzovaný soubor (např. do `.env` + `.gitignore`).

## Otevřené body / co si uživatel chce doladit sám
- `SILENCE_RMS` a `SILENCE_GAP` v hlavičce `loopback_translator.py` – ladění podle sluchu, záměrně neupravováno asistentem.
- Volitelně: logování výstupu do souboru (nebylo požádáno, jen zmíněno jako možnost).
- Volitelně: trvalé povolení PowerShell execution policy (`RemoteSigned`) pro pohodlnější `Activate.ps1` workflow.

---

Datum: 2026-09-14

## 10. Diagnóza pomalé odezvy (5-10 s)
Požadavek: funkčnost odpovídá zadání, ale odezva 5-10 s a nejistota, zda se překládá úplně vše.

- Vysvětleno, že `work_queue` je neomezená FIFO fronta – nic se nezahazuje kvůli rychlosti, jen se prodlužuje zpoždění, pokud přepis nestíhá.
- Zdroj latence rozebrán: `SILENCE_GAP` (0.8 s pevná prodleva), Whisper `small` na CPU (hlavní žrout, real-time faktor ~0.3-0.6×), zdvojená VAD filtrace (`vad_filter=True` navíc k RMS detekci v `capture()`), DeepL API round-trip.
- Navrženy možnosti: menší model, vypnutí `vad_filter`, GPU. Uživatel zvolil GPU (má NVIDIA RTX 4070).

## 11. Přechod na GPU (CUDA)
- Ověřeno `nvidia-smi` (RTX 4070, driver OK) a `ctranslate2.get_cuda_device_count()` = 1.
- Testovací načtení `WhisperModel('small', device='cuda', compute_type='float16')` prošlo bez chyby.
- V `loopback_translator.py` změněno `DEVICE = "cuda"`, `COMPUTE = "float16"` (dřív `"cpu"` / `"int8"`).
- Při prvním ostrém běhu s reálným audiem chyba: `Library cublas64_12.dll is not found or cannot be loaded` – model se načetl, ale samotný přepis na CUDA padal.
- Řešení bez instalace celého CUDA Toolkitu: doinstalovány pip balíčky `nvidia-cublas-cu12` a `nvidia-cudnn-cu12` do `.venv` (obsahují potřebné DLL: `cublas64_12.dll`, `cudnn64_9.dll` atd.).
- Do hlavičky `loopback_translator.py` přidán kód, který při startu najde složky `nvidia/cublas/bin` a `nvidia/cudnn/bin` v `site-packages` a přidá je přes `os.add_dll_directory()` + `PATH`, aby je ctranslate2 při běhu našel.
- Po fixu ověřeno naživo (skutečné anglické audio) – přepis i DeepL překlad proběhly správně, uživatel potvrdil znatelně kratší odezvu oproti CPU verzi.

## Otevřené body (aktualizace)
- `SILENCE_RMS` a `SILENCE_GAP` – stále záměrně neupravováno, ladění podle sluchu necháno na uživateli.
- Volitelně: logování výstupu do souboru – zatím nepožadováno.
- Volitelně: trvalé `Set-ExecutionPolicy RemoteSigned`.
- Bezpečnostní poznámka k DeepL klíči v `run.ps1` (čistý text) – stále platí.
- Pokud by i GPU odezva nestačila: zbývá možnost zkrátit `SILENCE_GAP` nebo zkusit jiný model (`base`/`medium`) – zatím neřešeno, GPU přechod odezvu uživateli stačil.

## 12. Spouštěcí/zastavovací dávkové soubory (`start.bat` / `stop.bat`)
Požadavek: dávkovací (.bat) soubor pro start a stop skriptu.

- `start.bat` a `stop.bat` jsou tenké obálky, které volají `start_helper.ps1` / `stop_helper.ps1` (skutečná logika v PowerShellu, dávkové soubory jen kvůli pohodlnému dvojkliku).
- `start_helper.ps1` spustí `run.ps1` v novém odděleném okně (`Start-Process`) a jeho PID uloží do `mumble_cz.pid`; pokud tam už běžící PID je, nespustí druhou instanci.
- `stop_helper.ps1` podle `mumble_cz.pid` najde proces a **rekurzivně zabije celý strom potomků** (ne jen přímé dítě) – `python.exe` spuštěný z `run.ps1` totiž při startu zakládá ještě jeden vnořený `python.exe` proces (běžné chování zdejších knihoven/venv, ne chyba), takže obyčejné `taskkill /T` nebo zabití jen jednoho PID nestačilo.
- Narazil jsem na dvě slepé uličky, obě opravené:
  1. Filtrace přes titulek okna (`taskkill /FI "WINDOWTITLE eq ..."`) je na Windows 11 s Windows Terminálem nebezpečná – všechny taby sdílí jeden `WindowsTerminal.exe` proces, takže by to mohlo zabít i jiná okna. Přepnuto na sledování přes PID soubor.
  2. `Start-Process -ArgumentList` se seznamem argumentů špatně rozdělil cestu k `run.ps1` na mezeře ve jménu složky ("Mumble do CZ") – PowerShell pak dostal jen ořezanou cestu a hned spadl. Opraveno explicitním uzavřením celé cesty do uvozovek v jednom řetězci argumentů.
- Otestován celý cyklus start → běh (ověřen PID i vnořené procesy) → stop → ověření, že nic nezůstalo viset. Funguje spolehlivě.

## 13. Instalátor pro další uživatele (jen NVIDIA GPU)
Požadavek: instalační soubor pro jiné uživatele, aby jen nainstalovali a pak používali start/stop. Zvažovány dvě varianty (NVIDIA + AMD) i univerzální auto-detekce, uživatel se nakonec rozhodl **jen pro NVIDIA** (`ctranslate2`/`faster-whisper` stejně neumí AMD/ROCm na Windows – AMD verze by běžela jen na CPU stejně pomalu jako původně).

- **Bezpečnostní oprava před distribucí:** `run.ps1` měl natvrdo v čistém textu uživatelův osobní DeepL API klíč – nešlo by to poslat dál. Klíč přesunut do samostatného `deepl_key.txt` (mimo `run.ps1`), `run.ps1` ho teď načítá ze souboru, pokud existuje. Uživatelův původní klíč zachován v `deepl_key.txt` na jeho stroji, funkčnost nezměněna.
- Přidán `requirements.txt` (PyAudioWPatch, faster-whisper, numpy, scipy, deepl, nvidia-cublas-cu12, nvidia-cudnn-cu12).
- Vytvořen `install.bat` → `install.ps1`, který:
  1. Ověří, že je v PC NVIDIA GPU (jinak instalaci ukončí s jasnou hláškou – tenhle instalátor je jen pro NVIDIA).
  2. Najde/nainstaluje Python 3.13 přes winget (pokud chybí).
  3. Vytvoří `.venv` (pokud ještě neexistuje).
  4. Nainstaluje balíčky z `requirements.txt`.
  5. Ověří, že GPU skutečně funguje (`ctranslate2.get_cuda_device_count()`).
  6. Pokud `deepl_key.txt` ještě neexistuje, nechá uživatele zadat vlastní DeepL klíč (volitelné, dá se přeskočit a doplnit později).
- Instalátor je idempotentní – otestován opakovaným spuštěním na tomto stroji, kde už vše bylo nainstalované: správně vše rozpoznal, nic nerozbil, jen ověřil stav (Python nalezen, `.venv` existuje, balíčky "already satisfied", GPU OK, klíč už nastaven → přeskočeno).
- Po instalaci ověřen i plný cyklus `start.bat` → `stop.bat` – funguje beze změny.

### Co při sdílení s dalšími lidmi NEKOPÍROVAT
Složku/zip pro předání dál je potřeba sestavit **bez**:
- `.venv` (velké, specifické pro stroj – instalátor si ho vytvoří sám),
- `deepl_key.txt` (osobní klíč – každý uživatel zadá svůj vlastní při instalaci),
- `mumble_cz.pid` (dočasný stav za běhu),
- `__pycache__` (pokud vznikne).

Zbytek (`.py`, `.ps1`, `.bat`, `requirements.txt`) stačí zkopírovat/zazipovat tak, jak je. Sestavení hotového zip balíčku zatím neprovedeno – nebylo výslovně požádáno, jen zmíněno jako další krok.

## 14. Jeden spustitelný instalační .exe
Požadavek: místo složky se skripty jeden spustitelný soubor, co nainstaluje úplně vše.

- Doinstalován nástroj `ps2exe` (PowerShell modul, kompiluje `.ps1` do `.exe`) přes `Install-PackageProvider NuGet` + `Install-Module ps2exe -Scope CurrentUser`.
- Vytvořen `build_installer.ps1` – vývojářský nástroj (nespouští ho koncový uživatel), který:
  1. Načte `loopback_translator.py`, `run.ps1`, `start.bat`, `stop.bat`, `start_helper.ps1`, `stop_helper.ps1`, `requirements.txt`, zakóduje je do base64.
  2. Vygeneruje jeden kombinovaný PowerShell skript, který tato data umí za běhu rozbalit do cílové složky a rovnou spustit stejnou instalační logiku jako `install.ps1` (NVIDIA GPU kontrola, Python/winget, `.venv`, balíčky, ověření GPU, DeepL klíč).
  3. Zkompiluje výsledek přes `Invoke-PS2EXE` do `dist\MumbleCZ_Install.exe` (~39 KB, konzolová aplikace, nepotřebuje admin práva).
- Cílová instalační složka: `%USERPROFILE%\Zvuk to CZ` (na přání uživatele přejmenováno z původního `MumbleCZ` – nejde jen o Mumble, ale o systémový zvuk obecně; Mumble-specifické řešení se bude řešit zvlášť později).
- Narazil jsem na pád `Read-Host` uvnitř zkompilovaného `.exe` při testu bez klávesnice (chyba `"value of argument obj is null"`) – opraveno obalením všech `Read-Host` volání v `install.ps1` do `try/catch`, aby selhání vstupu nikdy nezabilo celou instalaci (jen se přeskočí DeepL klíč). Po opravě přebuildováno.
- **Plně otestováno na tomto stroji** (čistá cílová složka, žádný zbytek předchozí instalace): `.exe` → rozbalení souborů → NVIDIA GPU nalezena → Python nalezen → `.venv` vytvořeno → balíčky nainstalovány (z pip cache, cca minuta) → GPU ověřeno (1 zařízení) → DeepL klíč přeskočen bez pádu → hotovo. Následně i `start.bat`/`stop.bat` v cestě s mezerou (`Zvuk to CZ`) fungovaly bez problémů (poučení z bodu 12 o mezerách v cestách se osvědčilo). Testovací instalace po ověření smazána.

### Co ještě zvážit
- `.exe` není podepsaný (self-built) – Windows SmartScreen při prvním spuštění pravděpodobně zobrazí varování "Windows chránil váš počítač", uživatel musí kliknout "Další informace" → "Přesto spustit". Nejde to obejít bez placeného code-signing certifikátu.
- Instalace stahuje balíčky z internetu (nutné připojení), není to plně offline instalátor – zejména `nvidia-cublas-cu12`/`nvidia-cudnn-cu12` jsou dohromady přes 1,2 GB ke stažení při prvním běhu.
- Pro přebalení po jakékoliv změně zdrojových souborů stačí znovu spustit `build_installer.ps1` (přečte aktuální verze souborů a přegeneruje `.exe`).

### Přejmenování MumbleCZ → ZvukCZ
Na přání uživatele přejmenováno v celém nástroji (odděleně od cílové instalační složky `Zvuk to CZ`, která už tak jmenovaná byla):
- PID soubor `mumble_cz.pid` → `zvukcz.pid` (v `start_helper.ps1` i `stop_helper.ps1`).
- Výstup instalátoru `dist\MumbleCZ_Install.exe` → `dist\ZvukCZ_Install.exe` (a odpovídající mezikrok `ZvukCZ_Install_generated.ps1`) v `build_installer.ps1`.
- Přebuildováno a znovu ověřeno kompletním cyklem instalace → start → stop na čisté složce, funguje beze změny chování.

## 15. Verze 1.1 – titulky jako overlay přes hru
Požadavek: výpis do příkazové řádky je nešťastný (další otevřené okno), zobrazit přeložený text jako titulky přes overlay nad hrou.

- Přidáno bez nových závislostí – `tkinter` (GUI) a `ctypes` (Windows API) jsou součástí standardní knihovny Pythonu.
- `Overlay` třída v `loopback_translator.py`: poloprůhledné černé okno bez rámečku, vždy navrchu, umístěné dole na středu obrazovky, klikatelné skrz (neblokuje myš/klávesnici ve hře).
- Restrukturalizace `__main__`: Tkinter potřebuje běžet v hlavním vlákně, takže `capture()` teď běží ve vlákně (dřív běžel v hlavním vlákně on-line), `transcriber()` zůstal ve vlákně jako dřív, hlavní vlákno teď drží `Overlay().run()` (mainloop). Konzolový výpis `EN:`/`CZ:` zůstal zachován navíc k overlayi (pro debug).
- Titulek na overlayi automaticky zmizí po `SUBTITLE_SECONDS` (7 s) bez nového textu.

### Slepé uličky při ladění (poučení)
Nejdřív jsem zkoušel klikání skrz naslepo (`SetWindowLongW` s `WS_EX_TRANSPARENT`), což opakovaně rozbilo vykreslování (okno zčernalo, text zmizel) – zkusil jsem několik oprav metodou pokus-omyl (barevný klíč misto alpha, `SetWindowPos` s `SWP_FRAMECHANGED`), nic nepomohlo. Uživatel správně upozornil, že si to mám nejdřív nastudovat místo zkoušení naslepo. Až dohledání funkčního referenčního řešení (`jfd02/tkinter-transparent-window` na GitHubu) ukázalo chybějící krok: **`SetWindowLongW` zruší barevný klíč, který si tkinter nastavil přes `-transparentcolor`, a je nutné po něm znovu explicitně zavolat `SetLayeredWindowAttributes(hwnd, 0, 255, LWA_COLORKEY)`** – tkinter to samo neobnoví. S touto opravou fungovalo na první pokus.
- Ověřeno i funkčně, ne jen vizuálně: `WindowFromPoint` na souřadnici overlaye vrátil okno ležící pod ním (ne overlay samotný) – potvrzuje, že klikání skrz opravdu funguje, ne jen že to tak vypadá.
- Otestováno vizuálně přes screenshoty (obrazovka se zachytávala přes `System.Drawing`/`System.Windows.Forms` v PowerShellu) a celý pipeline (capture + transcriber + overlay ve vláknech) spuštěn naostro bez chyby a bez zaseknutí.

### Otevřené body
- Overlay se nezobrazí v exkluzivním fullscreen módu her (jen v okně/borderless-windowed) – to je omezení Windows, ne skriptu. Nebylo zatím uživateli sděleno/ověřeno na konkrétní hře.
- `.exe` instalátor (`dist/ZvukCZ_Install.exe`) zatím nebyl přebuildován s touto verzí `loopback_translator.py` – na uživatelovo přání zůstává beze změny (viz bod 16).

## 16. Rozdělení na dva podprojekty – ZvukCZ1.0 a ZvukCZ1.1
Požadavek: "Mumble do CZ" je zastřešující projekt, ale obsahuje dva rozdílné podprojekty – konzolová verze (1.0) a verze s overlay titulky (1.1). Uživatel chtěl zdrojáky obou uložit do samostatných podadresářů. Zvoleno **kopírování** (ne přesun) – kořenová složka zůstává funkční přesně jak je (aktuálně = verze 1.1 s overlayem), podsložky jsou jen archivní kopie zdrojáků.

- `ZvukCZ1.1\` – kopie aktuálního stavu (`loopback_translator.py` s overlayem + sdílené soubory: `run.ps1`, `start.bat`, `stop.bat`, `start_helper.ps1`, `stop_helper.ps1`, `requirements.txt`, `install.ps1`, `install.bat`, `build_installer.ps1`, `deepl_key.txt`). Bez `dist\` – tahle verze zatím nebyla zabalená do `.exe`.
- `ZvukCZ1.0\` – **rekonstruovaná** verze `loopback_translator.py` z konverzace/historie edit (stav před bodem 15, tj. bez `Overlay` třídy, bez `tkinter`/`ctypes`, s `capture()` v hlavním vlákně a `KeyboardInterrupt` handlerem místo overlay mainloopu) + stejné sdílené soubory + `dist\` (obsahuje `ZvukCZ_Install.exe`, který byl skutečně zabalený z téhle – konzolové – verze).
- `.venv` zůstává jen v kořeni (sdílený, není duplikovaný – je velký a snadno znovu vytvořitelný přes `install.bat` v dané podsložce, kdyby bylo někdy potřeba spustit konkrétní verzi samostatně).
- `konverzace.md` zůstává jen v kořeni (průběžný deník celého projektu, není součástí "zdrojáků" jedné verze).

## 17. Živý test ZvukCZ1.1 ve hře – potvrzeno funkční
Uživatel spustil `start.bat` (verze s overlayem z kořenové složky) a vyzkoušel naživo ve hře. Potvrdil: **funguje to dobře** – titulky přes obraz hry fungují k spokojenosti. Skript poté zastaven přes `stop.bat` bez problémů.

## 18. Skryté okno PowerShellu při spuštění
Dotaz: musí při běhu zůstat otevřené okno PowerShellu, nebo to jde spustit "na pozadí"?

- `start_helper.ps1`: `Start-Process` teď spouští `run.ps1` s `-WindowStyle Hidden` (dřív se otvíralo viditelné okno s `-NoExit`), takže žádné okno konzole už není vidět – jen overlay s titulky.
- Výstup (stdout/stderr) se přesměrovává do `zvukcz.log` / `zvukcz.err.log` v kořeni projektu, aby šlo dohledat chybu, i když není vidět žádná konzole. Soubory se při každém startu přepíšou (ne append).
- Narazil jsem na známý bufferovací problém (viz bod 5.2) – bez skutečné konzole Python defaultně bufferuje `print()`, takže log zůstával prázdný, dokud proces neskončil. Opraveno přidáním `$env:PYTHONUNBUFFERED = "1"` přímo do `run.ps1` (natrvalo, netýká se to jen tohoto testu).
- Ověřeno: po startu není vidět žádné okno PowerShellu (jen prázdný overlay pruh dole), log soubory se plní za běhu v reálném čase, `stop.bat` skript i s potomky čistě ukončí, nic nezůstane viset.
- Na výslovné přání uživatele následně dorovnáno i do `ZvukCZ1.1\` – zkopírovány aktualizované `start_helper.ps1` a `run.ps1` (jediné dva soubory, které se touto úpravou změnily; `loopback_translator.py` a ostatní sdílené soubory beze změny). Archiv teď odpovídá živé kořenové kopii.

## 19. Overlay se přizpůsobuje délce textu
Dotaz: může se overlay automaticky roztahovat podle velikosti textu, místo pevné šířky/výšky?

- `Overlay._resize()`: box teď těsně obepíná text. Šířka se počítá přes `tkinter.font.Font.measure()` (skutečná šířka textu v pixelech daným fontem) až do stropu `MAX_WIDTH_RATIO` (70 % šířky obrazovky, stejně jako dřív) – kratší věta = užší box, delší věta = širší box. Nad stropem se text zalomí (`wraplength`) a výška boxu se dopočítá podle `label.winfo_reqheight()`, takže víceřádkové titulky se nezobrazí oříznuté.
- Box zůstává ukotvený dole na středu obrazovky – při změně výšky (víc řádků) roste směrem nahoru, spodní hrana zůstává na stejném místě (`BOTTOM_MARGIN`).
- Po prázdném textu (vypršení `SUBTITLE_SECONDS`) se box zmenší na minimální nenápadnou velikost místo mizení v pevném velkém rámu.
- Ověřeno přesným dotazem na `root.winfo_width()/height()` po `_resize()` (ne jen screenshoty) – krátký text dostal úzký box, dlouhý text narazil přesně na strop 1792 px (70 % z 2560 px obrazovky) a zalomil se na dva řádky s výškou 100 px místo jednořádkových 63 px. Následně ověřen i celý pipeline (capture+transcriber+overlay) naostro bez chyby v `zvukcz.log`.
- Poučení z bodu 15 dodrženo – žádné zbytečné pokusy naslepo, mechanismus byl navržen najednou a ověřen přesnými čísly místo opakovaného ladění.

## 20. Ozubené kolečko – nastavení overlaye (průhlednost, velikost, barva, šířka, přesun myší)
Požadavek: přidat "ozubené kolečko" s menu na nastavení průhlednosti/velikosti/barvy textu, možnost okno tahat myší po obrazovce a nastavit šířku.

- **Průhlednost skrz klikání skrz** – před zabudováním ověřeno izolovaně: `SetLayeredWindowAttributes` umí kombinovat `LWA_COLORKEY` (klíčovací barva mizí) a `LWA_ALPHA` (zbytek okna poloprůhledný) najednou (`dwFlags = LWA_COLORKEY | LWA_ALPHA`) – funguje to i s `WS_EX_TRANSPARENT` (klikání skrz), ověřeno vizuálně (vidět pozadí skrz box) i funkčně (`WindowFromPoint` stále vrací okno pod overlayem).
- **Ozubené kolečko** (⚙): samostatné malé `Toplevel` okno vedle boxu s titulky – hlavní box zůstává klikatelný skrz, ale potřeboval se JEDEN neprůhledný/klikatelný prvek, na který se dá sáhnout. Kolečko se při každém `_resize()` přepočítá vedle aktuálního boxu (ořezáno, aby nevyjelo mimo obrazovku).
- **Klik na kolečko** otevře/zavře panel nastavení (`Toplevel` s běžným titulkovým pruhem, ne klikatelný skrz – normální okno): slidery na průhlednost (10–100 %), velikost textu (12–40 pt), max. šířku (20–95 % obrazovky), tlačítko na barvu textu (`tkinter.colorchooser.askcolor`) a tlačítko "Resetovat pozici".
- **Tažení**: `ButtonPress`/`B1-Motion`/`ButtonRelease` na kolečku – pokud se myš posune o víc než pár px, považuje se to za tažení (posune celý box i kolečko, uloží novou pozici jako "kotvu"), jinak se bere jako klik (otevře nastavení). Bez tažení zůstává box na výchozí pozici dole na středu (stejně jako dřív).
- **Perzistence**: všechna nastavení (průhlednost, velikost, barva, max. šířka, pozice) se ukládají do `overlay_settings.json` vedle skriptu a načítají při startu – nastavení tak přežije restart skriptu.
- **Narazil jsem na skutečnou nekonečnou smyčku** (ne jen domnělou): otevření panelu s `Scale.set(...)` při vytváření sliderů spouštělo `command` callback, který volal `_resize()` → `update_idletasks()` → to znovu vyvolalo stejný `command` se stejnou hodnotou → `RecursionError: maximum recursion depth exceeded`. Přesně diagnostikováno přes počítadlo volání (potvrzeno stovky opakovaných volání `_resize` ze stejného callbacku), ne odhadem. Opraveno strážním porovnáním "změnila se hodnota oproti uloženému nastavení?" na začátku všech tří slider-callbacků (`on_opacity`, `on_font_size`, `on_width`) – pokud ne, callback se rovnou vrátí. Po opravě ověřeno: žádná smyčka (počítadlo zůstalo na 2 místo stovek).
- Ověřeno: panel se vykresluje správně (screenshot), průhlednost/barva/velikost fungují (opacity 0.5, žlutá barva, velikost 30 nastaveny bez pádu), tažení o (400,300) px posunulo kotvu přesně o stejnou hodnotu (1280,1340) → (1680,1640), nastavení se po doběhnutí skriptu správně uložilo a znovu načetlo ze souboru. Celý pipeline (capture+transcriber+overlay) ověřen naostro bez chyby v `zvukcz.log`.

## 21. Ozubené kolečko nahrazeno tray ikonkou (uživatel usoudil, že kolečko na poskakujícím boxu je rušivé)
Požadavek: kolečko zrušit, místo něj ikonka v system tray (vpravo dole u hodin) s pravým tlačítkem → menu. K tomu doplněno: konfigurovatelné klávesové zkratky (i "nahráním" stiskem, ne jen napsáním) a Start/Stop přepínač poslechu v tray menu.

- Nové závislosti: `pystray` (tray ikonka + menu), `Pillow` (vykreslení ikonky "Z" za běhu), `keyboard` (globální klávesové zkratky). Doplněno do `requirements.txt`.
- **Tray ikonka** se spouští ve vlastním vlákně (`pystray.Icon.run()` v `threading.Thread(daemon=True)`), běží nezávisle na Tkinter mainloopu. Menu: `Start/Stop` (dynamický text podle stavu), `Posunout titulky/Dokončit přesun` (dynamický text), `Nastavení...`, `Resetovat pozici`, oddělovač, `Ukončit`. Tooltip ikonky ukazuje "ZvukCZ – běží" / "pozastaveno".
- **Start/Stop** pozastaví jen poslech/přepis (`threading.Event`, `capture()` zahazuje zvuk místo zpracování, dokud je pauza) – **celý proces (tray, nastavení) běží dál**, na rozdíl od `stop.bat`, který zabije celý proces. Otestováno izolovaně (přepnutí stavu potvrzeno v testovacím logu, dvakrát tam a zpět).
- **Režim přesunu** nahradil tažení za kolečko: `Posunout titulky` v tray dočasně vypne klikání-skrz (`WS_EX_TRANSPARENT`) přímo na hlavním boxu, box dostane modrý okraj (`highlightbackground`) jako vizuální indikaci "teď jsi v editačním režimu", a tažení se dělá přímo na boxu (ne na samostatné ikonce). Druhé kliknutí na "Dokončit přesun" vrátí klikání-skrz a uloží pozici.
- **Cross-thread komunikace**: `pystray` callbacky (i budoucí `keyboard` callbacky) běží na cizích vláknech, ne na Tkinter hlavním vlákně – nesmí se z nich přímo sahat na widgety. Zaveden `command_queue` (stejný vzor jako `overlay_queue` u přepisu) – tray/zkratky tam jen vhodí řetězec/tuple, `_poll()` v hlavním vlákně (Tkinter) frontu čte a bezpečně provede skutečnou akci.
- **Klávesové zkratky**: pole v panelu nastavení pro "Nastavení" a "Přesun", buď se zkratka napíše ručně (např. `ctrl+alt+n`), nebo tlačítkem **"Nahrát..."** – to spustí `keyboard.read_hotkey()` na pozadí (blokující volání, proto ve vlastním vlákně) a výsledek pošle přes `command_queue` zpátky do textového pole. Uložení přeregistruje zkratky (`keyboard.unhook_all_hotkeys()` + nové `add_hotkey`).
- **Oprava přesnosti boxu**: při zavádění barevného okraje (`highlightthickness=3`) pro režim přesunu se objevila drobná neshoda – šířka boxu se dřív počítala ručně z `font.measure()` a nezahrnovala tloušťku rámečku. Opraveno použitím `label.winfo_reqwidth()` (stejně jako se už dělalo pro výšku), což automaticky zahrne i rámeček a je to konzistentní.
- Ověřeno naživo (uživatel): tray ikonka viditelná a klikatelná, `Nastavení...` otevřelo panel, klávesové zkratky (včetně nahrávání stiskem) potvrzeny funkční uživatelem. Celý pipeline (capture+transcriber+tray+overlay) ověřen i naostro přes `start.bat`/`stop.bat` bez chyby v `zvukcz.log`, po zastavení nezůstal žádný proces viset.

### Otevřené body
- Globální klávesové zkratky (`keyboard` knihovna) nemusí fungovat, pokud běží hra se zvýšenými právy (jako administrátor) a tenhle skript ne – Windows UIPI izoluje vstup mezi procesy s různou úrovní oprávnění. Neřešeno, jen k vědomí pro případ, že by zkratka v konkrétní hře nefungovala.

## 22. Ikonka v tray přizpůsobena (titulkový box "CZ" + červené přeškrtnutí při Stop)
- Uživatel z nabídnutých návrhů (mikrofon / titulkový box) vybral **titulkový box s "CZ"** – stejný vizuální styl jako samotný overlay. Vykresleno přes PIL (`rounded_rectangle` + `arialbd.ttf` text, zarovnáno na střed přes `textbbox`).
- Na přání přidáno **červené přeškrtnutí přes ikonku**, když je poslech na pauze (Stop) – `_make_tray_image(active: bool)` kreslí diagonální červenou čáru navíc. `_refresh_tray()` teď kromě titulku/menu mění i `tray_icon.icon` podle stavu `running_event`.
- Původní návrh s mikrofonem zachován jako referenční inspirace ze zaslaného Shutterstock obrázku, ale nepoužit doslovně (licencovaná grafika) – nahrazena vlastní jednoduchou kresbou.

## 23. Posun titulků myší nefungoval – najito a opraveno (rozsáhlé ladění)
Uživatel opakovaně hlásil, že přesun nejde (modrý okraj/editační režim se zapnul správně, ale box nešlo chytit ani přetáhnout myší – klik "propadával" na plochu pod ním, dokonce se místo přetažení objevovalo označování obsahu na ploše).

### Postup ladění (bez odbíhání do slepých uliček, systematicky)
1. Naprogramovaná simulace (přímé volání `_on_box_press/_on_box_drag/_on_box_release`) fungovala bezchybně – potvrdilo to, že samotná logika tažení/ukládání pozice je v pořádku, problém je v cestě od skutečné myši ke kódu.
2. Ověřeno přes `WindowFromPoint` (uvnitř i **z externího PowerShell procesu**, aby se vyloučilo, že jde jen o artefakt dotazu z vlastního procesu) – bod uprostřed boxu trvale patřil ploše (`explorer.exe`/`SysListView32`), ne naší aplikaci, i když `GetWindowLongW` správně hlásil `WS_EX_TRANSPARENT=False`.
3. Vyzkoušeny a **zamítnuty** postupně: přebarvení pozadí při přesunu (řešilo jiný, vedlejší problém s klíčovací barvou v odsazení, ne hlavní příčinu), přehození pořadí `configure(bg=...)` vs. vypnutí klikání-skrz, `SetWindowPos` s `SWP_FRAMECHANGED` aplikované jen na `WS_EX_TRANSPARENT`.
4. Až cílený web research (GitHub issue `openai/codex#43200` – přesně stejný jev u jiného overlay nástroje: *"WS_EX_LAYERED breaks hit testing"*) odhalil skutečnou příčinu: **není to `WS_EX_TRANSPARENT`, kdo za to může, ale samotné `WS_EX_LAYERED`** – jakmile je nastavené, `WindowFromPoint`/klik "vidí" okno pod naším, bez ohledu na `WS_EX_TRANSPARENT`.
5. **Oprava**: `_set_clickthrough(False)` (vstup do režimu přesunu) teď odebírá `WS_EX_LAYERED` úplně (ne jen `WS_EX_TRANSPARENT`) + `SetWindowPos` s `SWP_FRAMECHANGED`. Bez `WS_EX_LAYERED` okno přestává být průhledné/klikatelné-skrz úplně, což nevadí – `_enter_move_mode` zároveň zneprůhlední i barvu pozadí na plnou `#111111`, takže vizuálně nic nechybí. Při opuštění režimu přesunu se `WS_EX_LAYERED` (+ barevný klíč + alfa) vrátí zpět beze změny oproti původnímu, dávno ověřenému chování.
6. Ověřeno znovu přes `WindowFromPoint` (in-process i externě) – bod teď patřil naší vlastní aplikaci (PID python.exe), ne ploše. Uživatel following potvrdil: **posun teď funguje**.

**Poučení pro příště**: i po tomhle nálezu je jasné, že `WS_EX_LAYERED` na Windows má víc skrytých vedlejších efektů, než dokumentace přiznává (viz i dřívější bod 15 o `SetLayeredWindowAttributes`) – při jakémkoliv budoucím problému s klikáním/hit-testingem na tomhle typu okna zkusit napřed odebrat `WS_EX_LAYERED` úplně, ne jen ladit `WS_EX_TRANSPARENT`/colorkey/alfa zvlášť.

## 24. Archiv ZvukCZ1.1 dorovnán (před živým testem ve hře)
Na výslovné přání uživatele zkopírovány všechny aktuální soubory (`loopback_translator.py`, `run.ps1`, `start.bat`, `stop.bat`, `start_helper.ps1`, `stop_helper.ps1`, `requirements.txt`, `install.ps1`, `install.bat`, `build_installer.ps1`, `deepl_key.txt`) do `ZvukCZ1.1\`. Archiv teď odpovídá živé kořenové kopii včetně tray ikonky, režimu přesunu, klávesových zkratek a Start/Stop pauzy.

## 25. Doladění po prvním živém testu ve hře: duch-čtvereček, mizení titulku, latence, nastavitelné parametry řeči
Po prvním opravdovém hraní uživatel nahlásil tři věci, postupně vyřešeno:

### a) "Duch" čtverečku po dokončení přesunu
Po `Dokončit přesun` zůstal na staré pozici (odkud se táhlo) vykreslený zbytek boxu, dokud se ta část obrazovky znovu nepřekreslila. Opraveno vynuceným krátkým skrytím/zobrazením okna (`root.withdraw()` → `root.deiconify()` → znovu `-topmost`) v `_exit_move_mode()`, což DWM donutí danou oblast znovu překreslit.

### b) Malý čtvereček zůstával i po Stop / mezi titulky
Ukázalo se, že `_resize()` měl tvrdé minimum 40 px šířky - takže i "prázdný" box nikdy úplně nezmizel, jen se zmenšil na drobný čtvereček (viditelný jak po `Stop` v tray, tak běžně mezi titulky). Přepracováno: `_resize()` teď při prázdném textu rovnou **schová celé okno** (`root.withdraw()`), a při skutečném textu ho zase ukáže (`deiconify()` + znovu `-topmost`, pro jistotu že se nic neresetovalo). Tray `Stop` teď volá `_resize(" ")`, což okno rovnou schová, ne jen vyprázdní.
- Vedlejší dopad: režim přesunu potřeboval dořešit případ, kdy se do něj vstupuje v době, kdy zrovna nic neběží (okno by bylo schované, nešlo by ho chytit) - `_enter_move_mode()` v tom případě zobrazí placeholder text `(přesuň mě)`, a `_exit_move_mode()` ho zase korektně schová, pokud mezitím nedorazil skutečný titulek.

### c) "Odezva 5-10s" nebyl výkon, ale délka bez pauzy
Přidáno dočasné měření času přímo do logu (`[čas: přepis=…s překlad=…s audio=…s fronta=…]`) u každé přeložené věty. Výsledek: **přepis 0.2-0.5s, překlad 0.2-0.7s, fronta vždy 0** - GPU pipeline je naprosto v pořádku. Skutečná příčina: `MAX_SPEECH` bylo 15s, a při souvislém komentáři/vyprávění bez přirozené pauzy (video guide styl) se čekalo na celý až 15s dlouhý úsek řeči, než se poslal na přepis - to uživatel vnímal jako "latenci". Řešení: zkráceno na `MAX_SPEECH = 7.0` (uživatel zvolil z nabídnutých možností), takže se při souvislém mluvení titulky objevují min. každých ~7s místo až 15s. Měření zůstalo v kódu natrvalo (užitečné do budoucna, ne jen na jedno ladění).

### d) Parametry rozpoznávání řeči přesunuty do nastavení
Uživatel chtěl `MAX_SPEECH` i ostatní "na mě" (uživatele) laděné parametry (`SILENCE_RMS`, `SILENCE_GAP`, `MIN_SPEECH`) dostupné z panelu nastavení, ne jen napevno v kódu.
- Refaktor: `SILENCE_RMS`/`SILENCE_GAP`/`MIN_SPEECH`/`MAX_SPEECH` už nejsou konstanty, ale položky v `DEFAULT_SETTINGS` (`silence_rms`, `silence_gap`, `min_speech`, `max_speech`).
- Zaveden **jeden sdílený globální `settings` slovník** (místo `Overlay.__init__` volajícího vlastní `load_settings()`), který čte `capture()` (běží ve vlastním vlákně) i `Overlay`/panel nastavení (Tk vlákno) - úpravy ze slideru jsou tak okamžitě vidět i ve vlákně, co zpracovává zvuk. Čtení/zápis jednotlivých klíčů slovníku je v CPythonu dost atomické (GIL), takže žádné zamykání nebylo potřeba.
- V panelu nastavení přibyla sekce "Rozpoznávání řeči" se 4 dalšími slidery (citlivost na ticho, délka ticha pro konec věty, min. a max. délka promluvy), se stejnou ochranou proti zbytečnému opakovanému volání jako ostatní slidery.
- Vše ověřeno programovaticky (přesný scénář: start schovaný → vstup do přesunu s placeholder textem → konec přesunu → zase schovaný) i naostro přes `start.bat`/`stop.bat` bez chyby. Uživatel potvrdil: **"za mě v pořádku"**.

## 26. Git repozitář jako záloha
Požadavek: udělat zálohu všeho, git atd., a pokračovat dál.

- Git nebyl na stroji nainstalovaný – doinstalováno přes `winget install --id Git.Git` (stejný postup jako dřív u Pythonu).
- Vytvořen `.gitignore` **před** prvním commitem (kriticky důležité kvůli osobnímu DeepL klíči): vynechává `deepl_key.txt` (existuje ve 3 kopiích – kořen, `ZvukCZ1.0`, `ZvukCZ1.1`), `overlay_settings.json`, `.venv/`, `__pycache__/`, a běhové soubory `zvukcz.log`/`zvukcz.err.log`/`zvukcz.pid`.
- Před commitem výslovně ověřeno (ne jen předpokládáno): `git check-ignore -v` potvrdil všechny 3 kopie `deepl_key.txt` i `overlay_settings.json` jako ignorované; `git status --ignored` totéž; navíc `grep` přes celý projekt po samotném řetězci klíče nenašel žádný soubor, kde by zůstal zapsaný natvrdo (jistota, že ani starší verze `run.ps1` v archivech klíč neobsahují).
- `dist/` (obsahuje `ZvukCZ_Install.exe`) záměrně **není** v `.gitignore` – je to malý, záměrně zmrazený artefakt, který si uživatel výslovně nepřál nechat automaticky přebuildovávat, dává smysl ho mít verzovaný.
- Prvotní commit: `46b85ce` – 36 souborů (kořen + oba archivy `ZvukCZ1.0`/`ZvukCZ1.1` + `.gitignore`), žádné tajné soubory uvnitř. `git status` po commitu čistý.
- Repozitář je zatím jen lokální (žádný vzdálený remote/GitHub) – jen lokální historie/záloha, jak bylo požádáno.

## 27. ZvukCZ1.1 jako desktopová aplikace – instalátor se zástupcem na ploše
Požadavek: udělat z verze 1.1 pořádnou Windows aplikaci, instalační balíček s umístěním na plochu.

- Vytvořena `zvukcz.ico` (Python/PIL, `Image.save(..., format="ICO", sizes=[...])`) – stejný vizuál jako tray ikonka (titulkový box "CZ"), více rozlišení pro ostré zobrazení na ploše i v Průzkumníku.
- `build_installer.ps1` rozšířen: `zvukcz.ico` se teď taky zabaluje do instalátoru; po dokončení instalace se přes `WScript.Shell` COM objekt vytvoří zástupce `ZvukCZ.lnk` na ploše (`[Environment]::GetFolderPath("Desktop")`), který **přímo** spouští `powershell.exe -WindowStyle Hidden -File start_helper.ps1` (obchází `start.bat`, takže žádné blikající okno konzole ani "Press any key" – čisté chování jako u běžné appky).
- Drobná oprava mimoto: `_quit()` (Ukončit v tray) teď maže i `zvukcz.pid`, které předtím po ukončení tímhle způsobem zůstávalo osiřelé (všiml si uživatel – "dyť jsem dal stop a ukončit", ale `Test-Path zvukcz.pid` pořád vracelo `True`; proces sám ale běžet nezůstal, jen soubor).
- Sestaveno v `ZvukCZ1.1\dist\ZvukCZ_Install.exe` (spuštěno `build_installer.ps1` přímo ze složky `ZvukCZ1.1`, ne z kořene – takže balí verzi 1.1, ne kořenovou/1.0).
- **Ověřeno naostro end-to-end**: spuštěn skutečný instalátor → nainstaloval do `%USERPROFILE%\Zvuk to CZ` (balíčky vč. `pystray`/`Pillow`/`keyboard`) → vytvořil `ZvukCZ.lnk` na ploše se správnými vlastnostmi (cíl, argumenty, ikona, popis) → **dvojklik na zástupce appku opravdu tiše spustil** (žádné okno, model se načetl, tray proces běžel) → zastaveno přes `stop_helper.ps1`.
- Testovací instalace + zástupce po ověření na uživatelovo přání **smazány** (byl to jen test) – zůstává hotový `ZvukCZ1.1\dist\ZvukCZ_Install.exe`, který si uživatel může spustit sám, až bude chtít appku reálně nainstalovat.

## 28. Zátěžový test – appka + 2× EVE Online + YouTube video
Uživatel chtěl appku reálně nainstalovat (natrvalo) a otestovat zatížení systému při současném běhu hry a videa na YouTube.

- Appka nainstalována naostro přes `ZvukCZ_Install.exe` do `%USERPROFILE%\Zvuk to CZ`, tentokrát **ponechána** (na rozdíl od předchozích testů). Vlastní `deepl_key.txt` dokopírován ručně, ať test odpovídá reálnému používání i s překladem (instalátor ho záměrně nevyplňuje sám).
- Spuštěno přes zástupce na ploše (`ZvukCZ.lnk`) – stejně, jak by to dělal běžný uživatel.
- Uživatel pustil **dva** klienty EVE Online zároveň (Prcimir + Zwjar) a video na YouTube.
- Naměřeno (`Get-Counter` pro GPU Engine/GPU Process Memory, `Get-Process` pro CPU/RAM, s odstupem pro výpočet reálného CPU % z kumulativního času):
  - CPU appky: ~0,4 % z celkového výkonu stroje (28 logických jader) – prakticky zanedbatelné.
  - GPU appky v klidu: 0 % (žádný engine).
  - GPU appky na špičce (zachyceno přesně během aktivního přepisu – potvrzeno růstem `zvukcz.log` v okně vzorkování): ~7,4 %.
  - GPU paměť appky: ~926 MB (srovnatelné s jedním EVE klientem, ale jde jen o rezervovanou paměť modelu, ne o výpočetní zátěž).
  - RAM appky: ~861 MB, stabilní mezi měřeními (žádný náznak úniku paměti v rámci testovacího okna).
  - Fronta zpracování (`work_queue`) zůstala po celou dobu na 0, přepis/překlad stejně rychlé jako v klidu (0,3–0,6 s / 0,25–0,3 s) i s oběma hrami a videem běžícími zároveň.
- Pro srovnání každý EVE klient sám o sobě táhne GPU (3D engine) na ~35–37 %. Appka je vedle toho zanedbatelná.
- Závěr sdělený uživateli: appka reálně systém nezatěžuje. Uživatel se rozhodl **nechat appku nainstalovanou a běžící**.

## 29. Nový podprojekt "Mumble bot" – bot přímo v Mumble, zvuk po jednotlivých mluvčích
Požadavek: vrátit se k původnímu tématu "Mumble" (zatím odloženo v bodě 27 dřívější historie) – bot, co se připojí přímo do Mumble serveru (ne loopback systémového zvuku) a umí tedy oddělit jednotlivé mluvčí. Uživatel výslovně požádal **nejdřív prozkoumat dokumentaci**, než se začne cokoliv stavět ("ať zase nelaborujeme na prázdno").

### Research (přes fork agenta, jen čtení/hledání)
- Jediná reálná knihovna: **`pymumble`** (na PyPI přesně tento název; `pymumble_py3` je jen název GitHub větve, ne balíčku). Málo udržovaná (autor hledá nástupce), ale funkční. Licence GPL-3.0 (na rozdíl od zbytku projektu).
- Umí zvuk **po jednotlivých mluvčích** přes callback `on_sound(user, soundchunk)` – přesně to, co WASAPI loopback neumí.
- Bot je vidět jako normální připojený uživatel v kanálu (sociálně viditelné, na rozdíl od lokálního zachytávání zvuku).
- Potřebuje certifikát (`certfile`/`keyfile`), zvuk chodí jen když daný uživatel opravdu mluví (gated jeho vlastní VAD/PTT).

### Testovací server
Uživatel neměl zrovna přístup do své běžné Mumble místnosti, tak jsem prohledal možnosti (GuildBit, RedMumble, Mumble.com) a na jeho pokyn rovnou přes `claude-in-chrome` **založil dočasný server na GuildBit.com** (bez registrace, zdarma, 4 hodiny): `iron.guildbit.com:50003`, heslo vygenerováno tlačítkem na stránce. Uživatel se připojil vlastním Mumble klientem.

### Sestavení a ladění (postupně, s ověřováním na každém kroku)
1. **Samostatné venv** pro "Mumble bot" – `pymumble` vyžaduje pevně `protobuf==3.12.2`, což by v společném venv rozbilo `onnxruntime`/`faster-whisper` v ZvukCZ (`protobuf>=4.25.8`). Omylem nainstalováno nejdřív do sdíleného venv, ihned zjištěno a opraveno (odinstalováno, `protobuf` vrácen na `7.36.1`, ověřeno že ZvukCZ funguje dál). V dedikovaném venv pro Mumble bota nakonec `pip` samo doresolvovalo kompatibilní `onnxruntime==1.26.0`, takže `faster-whisper` i `pymumble` fungují ve stejném venv bez konfliktu.
2. **Chybějící `opus.dll`** – `opuslib` (závislost `pymumble`) potřebuje nativní Opus knihovnu, kterou Windows nemá. Získána z balíčku `PyOgg` (obsahuje předkompilované `opus.dll` pro Windows) a přidána do `PATH` za běhu stejným trikem jako cuBLAS/cuDNN v ZvukCZ.
3. **`ssl.wrap_socket()` odstraněno v Pythonu 3.12+** – `pymumble` na něm staví TLS spojení. Přidána kompatibilní náhrada přes `ssl.SSLContext` (zjištěno rovnou z tracebacku, ne hádáním).
4. **Certifikát** vygenerován přes `openssl` (bundlovaný s Git for Windows, `C:\Program Files\Git\usr\bin\openssl.exe`) – `bot_cert.pem`/`bot_key.pem`, 10 let platnost, self-signed.
5. Minimální test připojení + příjmu zvuku (`test_connect.py`) – při prvním pokusu žádný zvuk nedorazil. Diagnostikováno systematicky (ne odhadem): rozšířený debug test (`test_debug.py`) ukázal, že control kanál (ping/pong, seznam uživatelů) funguje normálně, ale žádný audio paket nikdy nedorazil ani přes 20s okno. Ukázalo se, že **uživatel prostě neměl aktivní mikrofon** – po zapnutí zvuk hned přišel čistě (~250 fragmentů, 20ms/1920B každý, správně přiřazeno ke jménu mluvčího).

### Plný pipeline (`mumble_bot.py`)
- `SpeakerBuffer` – stejná logika ticho/konec věty/max délka jako `capture()` v ZvukCZ, ale **samostatná instance na každého mluvčího** (klíčováno podle Mumble session id), audio přeresamplováno z 48000 Hz (Mumble) na 16000 Hz (Whisper) stejně jako dřív.
- `transcriber()` – stejný `WhisperModel` (small/cuda/float16), stejné DeepL napojení (`deepl_key.txt` zkopírován ze ZvukCZ).
- **Overlay zkopírován beze změny logiky** ze ZvukCZ1.1 (auto-přizpůsobení velikosti, klikání skrz přes odebrání `WS_EX_LAYERED` v režimu přesunu, tray ikonka, klávesové zkratky, panel nastavení včetně parametrů rozpoznávání řeči) – jen titulek teď obsahuje i jméno mluvčího (`"Jméno: text"`).
- Vlastní `overlay_settings.json` v `Mumble bot\` složce (oddělené od ZvukCZ, ne sdílené).
- **Ověřeno naostro end-to-end**: uživatel řekl anglicky "Hello, how are you?" do Mumble mikrofonu → bot přepsal → přeložil → zobrazil na overlay jako "Spoock: Ahoj, jak se máš?". Uživatel potvrdil, že titulek viděl.
- Po úspěšném testu bot na uživatelovo přání ukončen.

### Poznámky
- Připojovací údaje k Mumble serveru jsou zatím natvrdo v hlavičce `mumble_bot.py` (test server GuildBit vyprší po 4 hodinách) – při přechodu na ostrý/vlastní server je potřeba je tam přepsat.
- `.gitignore` doplněn o `bot_key.pem` (soukromý klíč certifikátu bota).
- Vytvořen `Mumble bot\README.md` s instalačními a technickými poznámkami pro budoucí referenci.

## 30. Odinstalační skript pro ZvukCZ1.1 (`uninstall.bat`)
Po dotazu, jak se dá appka odinstalovat (dosud žádný formální odinstalátor neexistoval), uživatel zvolil z nabídnutých možností **přidat `uninstall.bat` do instalátoru** – jen pro budoucí použití, výslovně **ne** odinstalovat aktuální reálně nainstalovanou appku hned teď.

- Vytvořen `uninstall_helper.ps1` (v kořeni i `ZvukCZ1.1\`): po potvrzení textem "ano" nejdřív zastaví běžící appku (zavolá `stop_helper.ps1`, pokud existuje), smaže zástupce `ZvukCZ.lnk` na ploše, a nakonec smaže celou instalační složku.
- **Sebe-mazání složky** vyžaduje trik – skript běží zevnitř složky, kterou má smazat, takže se nemůže smazat přímo (zámek souboru). Řešeno spuštěním odděleného procesu mimo složku (v `%TEMP%`), který 2 s počká a pak složku smaže; po jeho spuštění už nesmí následovat žádný blokující dotaz (`Read-Host`/`pause`), jen se vypíše hláška a skript skončí.
- `uninstall.bat` je tenká obálka bez `pause` na konci (ze stejného důvodu jako výše).
- `build_installer.ps1` rozšířen o zabalení obou nových souborů (`uninstall.bat`, `uninstall_helper.ps1`) do instalátoru; `install.ps1` doplněn o zmínku "Odinstalace: uninstall.bat" v závěrečné hlášce.
- `ZvukCZ1.1\dist\ZvukCZ_Install.exe` přebuildován – ověřeno, že všech 10 souborů (vč. nových dvou) je zabaleno.
- **Testování bylo záměrně omezené**: instalátor cílí vždy na pevnou cestu `%USERPROFILE%\Zvuk to CZ`, což je přesně místo reálné, uživatelem ponechané instalace z bodu 28 – spustit tam `uninstall.bat` by ji smazalo. Proto ověřen **jen samotný rizikový mechanismus** (sebe-mazání složky) izolovaně v `%TEMP%\UninstallMechTest` s minimálním testovacím skriptem (bez mazání zástupce, bez volání `stop_helper.ps1`) – složka existovala před spuštěním, po 4 s `Test-Path` vrátilo `False`. Reálná instalace uživatele nebyla nijak dotčena.
- Soubory synchronizovány mezi kořenem a `ZvukCZ1.1\` (stejný pattern jako u předchozích funkcí).

## 31. Doplnění DeepL návodu do instalátoru ZvukCZ1.1

Datum: 2026-09-15

Uživatel se zeptal, jestli instalátor informuje o nutnosti DeepL API klíče. Odpověď: krok 6 se ptá, ale bez odkazu, kde klíč získat.

- Přidán odkaz na `https://www.deepl.com/pro-api` (DeepL API Free tier registrace) do `install.ps1` (kořen i `ZvukCZ1.1\`), krok 6 nyní vypisuje odkaz + odkazuje na README.
- Vytvořen nový `README.md` (kořen i `ZvukCZ1.1\`) s návodem: kde se zaregistrovat, kde v DeepL účtu najít klíč, kam ho vložit (`deepl_key.txt`), plus stručný přehled instalace/spuštění/ovládání appky.
- `build_installer.ps1` (kořen i `ZvukCZ1.1\`) rozšířen o `README.md` do seznamu balených souborů.
- Commit `e316be0` (zdrojové změny), poté na přání uživatele přebuildován `ZvukCZ1.1\dist\ZvukCZ_Install.exe` (100 352 B, 11 souborů vč. README) – commit `a5b7563`.
- Root/`ZvukCZ1.0` instalátor (`dist\ZvukCZ_Install.exe`, stará konzolová verze) záměrně nepřebuildován – zůstává zmrazený artefakt jako dřív.

## 32. Zahájení Linux verze (AMD GPU / bez GPU) – research fáze

Uživatel chce novou verzi appky pro Linux, cílovka AMD grafická karta nebo žádná GPU (NVIDIA řešeno, o tu teď nejde). Testovat to nejde interaktivně – uživatel může appku pasivně vyzkoušet jen na svém Debianu, bez debug smyčky se mnou. Na jeho výslovné přání proběhl **nejdřív research přes dokumentaci** (fork agent, jen čtení/hledání, žádný kód), než se začne cokoliv psát – stejný postup jako u bodu 29 (Mumble bot).

### Výsledky researche (2026-09-15)
1. **AMD GPU přepis**: `CTranslate2` (backend `faster-whisper`) nedávno (2026-02, PR #1989) přidal ROCm/HIP podporu upstream, ale **jen jako GitHub-release wheely, ne přes `pip install`** (na PyPI je pořád jen CPU/CUDA). Zralejší cross-vendor alternativa: `whisper.cpp` s Vulkan backendem (`-DGGML_VULKAN=1`) – funguje na AMD i bez ROCm toolkitu, ale je to jiný engine než faster-whisper.
2. **Zachytávání zvuku**: `sounddevice`/PortAudio + výběr `.monitor` zařízení funguje stejně na čistém PulseAudio i na PipeWire-pulse kompatibilní vrstvě (Debian 12 default), bez rootu – spolehlivé, žádný zásadní problém.
3. **Click-through overlay**: na X11 proveditelné (Xlib XShape input-shape, jako `WS_EX_LAYERED`/`WS_EX_TRANSPARENT` na Windows), na **Wayland (GNOME, Debian 12 default session) zásadně nejde** běžnou Tk/Xlib appkou – layer-shell protokol funguje jen na wlroots/KDE, ne na GNOME Wayland.
4. **Tray ikonka**: `pystray` + AppIndicator funguje, ale potřebuje systémové (apt) balíčky navíc (`python3-gi`, `gir1.2-ayatanaappindicator3-0.1`, `gir1.2-gtk-3.0`) – nejde čistě přes pip.
5. **Globální zkratky**: `keyboard` (balíček používaný ve Windows verzi) na Linuxu vyžaduje root/skupinu `input` – nevhodné. `pynput` funguje na X11 bez rootu. Na **Wayland globální zkratky nejdou** žádnou knihovnou (bezpečnostní model kompozitoru), jediná legitimní cesta je nový XDG Desktop Portal `GlobalShortcuts`, na GNOME nekonzistentně podporovaný.

### Doporučená architektura (z researche, zatím NEODSOUHLASENO uživatelem)
- Přepis: CPU (int8) jako spolehlivý default, GPU akcelerace (ROCm wheel nebo whisper.cpp+Vulkan) jen jako volitelný/experimentální krok.
- Zvuk: `sounddevice` + `.monitor` zařízení.
- Overlay: plně funkční jen na X11 session; na Wayland detekovat `XDG_SESSION_TYPE` a degradovat s jasnou hláškou (jen konzole/log).
- Tray: `pystray`+AppIndicator, systémové závislosti zdokumentovat.
- Zkratky: `pynput` na X11, na Wayland vypnout s hláškou.

### Rozhodnutí uživatele
1. **Wayland/overlay**: uživatel zvolil variantu **"bez overlaye úplně pro v1"** – žádný Xlib click-through kód, jen konzolový/log výstup, bez ohledu na X11/Wayland.
2. **GPU v1**: uživatel zvolil **"jen CPU"** – žádný GPU kód v v1.

Vzhledem k volbě "bez overlay" logicky odpadly i tray ikonka a globální zkratky (byly by k ničemu bez overlaye, který by ovládaly) – v1 je tedy funkčně obdoba konzolové `ZvukCZ1.0` z Windows, jen portovaná na Linux/CPU.

### Implementace v1 (2026-09-15)
Vytvořen nový podadresář `ZvukCZ-Linux/` (vedle `ZvukCZ1.0`/`ZvukCZ1.1`):
- `loopback_translator.py` – port `ZvukCZ1.0`/loopback_translator.py na Linux: `pyaudiowpatch` → `sounddevice` (hledání `.monitor` zařízení přes `sd.query_devices()`, `sd.RawInputStream` blocking read), `DEVICE="cpu"`/`COMPUTE="int8"` natvrdo (žádná GPU/DLL logika), `MAX_SPEECH=7.0` (převzato z pozdějšího Windows doladění, bod 25c). Přepis/DeepL logika beze změny oproti Windows verzi.
- `requirements.txt` – `sounddevice`, `faster-whisper`, `numpy`, `scipy`, `deepl` (bez `PyAudioWPatch`, bez nvidia balíčků).
- `install.sh` – kontrola Pythonu, informativní kontrola `pactl` (PulseAudio/PipeWire), `.venv`, instalace balíčků, DeepL klíč (stejný odkaz+README pattern jako u Windows `install.ps1`).
- `run.sh` / `start.sh` / `stop.sh` – bash/sh obdoba `run.ps1`/`start_helper.ps1`/`stop_helper.ps1`: `start.sh` pouští `run.sh` přes `nohup … &` (ne `setsid` – ten by fork-oval a `$!` by ukazoval na už skončený proces, ověřeno úvahou nad chováním util-linux `setsid`), PID do `zvukcz.pid`, log do `zvukcz.log`/`zvukcz.err.log`; `stop.sh` posílá nejdřív SIGTERM (+ `pkill -P` pro případné přímé potomky), po 5 s čekání případně SIGKILL.
- `README.md` – vysvětluje rozdíly oproti Windows verzi (proč bez overlaye/GPU), instalaci, DeepL klíč, spuštění/zastavení, řešení problémů (`.monitor` zařízení nenalezeno apod.).

**Ověřeno, co šlo ověřit bez cílového stroje** (nejde to tu spustit naostro – jen pasivní test na uživatelově Debianu):
- `bash -n` na všech 4 shell skriptech – syntakticky OK.
- `python -m py_compile loopback_translator.py` – syntakticky OK.
- API `sounddevice` (`query_devices()` klíče `name`/`index`/`max_input_channels`/`default_samplerate`, `RawInputStream` konstruktor a `read(frames)` → `(data, overflowed)`) ověřeno přes WebFetch proti oficiální dokumentaci `python-sounddevice.readthedocs.io`, ne odhadem.
- `find_monitor_device()` použije `d["index"]` z vráceného slovníku (ne pozici v enumerate), pro robustnost.

Zatím **necommitnuto** (čeká se na explicitní pokyn, jako u předchozích bodů).

## 33. Živý test ZvukCZ-Linux přes SSH na reálném Debianu

Uživatel nabídl reálný přístup na Debian 12 stroj v síti (`192.168.86.192`, hostname `debian-tuya`) místo jen "pasivního" testu. Vygenerován dedikovaný SSH klíč (`~/.ssh/id_ed25519`, komentář `claude-code-zvukcz-test`), uživatel ho přidal do `authorized_keys` uživatele `root`. Přístup přes SSH jako root.

### Zjištěný hardware/prostředí
- 2jádrový Intel Celeron N3000 @1.04GHz, **bez AVX2** (jen SSE4.1/4.2) - výrazně slabší stroj, ale reprezentativní pro "bez GPU" scénář.
- Debian 12.15, PipeWire 0.3.65 + pipewire-pulse + wireplumber nainstalováno, GNOME desktop nainstalován, ale **žádný uživatel není aktuálně přihlášený v grafické session** (jen root přes SSH/tmux) - PipeWire jako per-user služba tedy neběží.
- Uživatelský účet `mojmir` existuje, ale bez aktivní session.

### Co se otestovalo a opravilo
1. **`install.sh` end-to-end** (čistá instalace, `rm -rf .venv` + spuštění) - všechny balíčky (`sounddevice`, `faster-whisper`/`ctranslate2`, `numpy`, `scipy`, `deepl`) mají hotové wheely pro Debian 12/Python 3.11, žádné kompilování, žádný pád.
2. **Nalezena a opravena chybějící systémová závislost**: `sounddevice` na Linuxu (na rozdíl od Windows/macOS wheelu) **nebalí PortAudio** - `import sounddevice` rovnou spadl na `OSError: PortAudio library not found`. Opraveno: `install.sh` teď kontroluje/instaluje `libportaudio2` přes apt (krok 2, nový), README doplněno.
3. **Ověřeno, že `faster-whisper`/`ctranslate2` na CPU bez AVX2 neshodí** (obava z researche v bodě 32 se nepotvrdila jako blokující - ctranslate2 má fallback bez AVX2).
4. **Klíčový výkonnostní nález** (naměřeno, ne odhadnuto): na tomhle CPU je model `small` i `base` **6-15× pomalejší než reálný čas** (transkripce 7s zvuku trvala 43-54s) - nepoužitelné živě, zpoždění by se donekonečna prodlužovalo. Model `tiny` běžel v **0.77× reálného času** (rychleji než realtime, použitelné). Opraveno: `MODEL_SIZE` je teď konfigurovatelný přes env proměnnou `ZVUKCZ_MODEL_SIZE` (výchozí `base`), README má naměřenou tabulku a návod na přepnutí na `tiny`.
5. **`find_monitor_device()` chybová hláška** ověřena naživo - v prostředí bez aktivní PipeWire user session (jako tady) appka čistě a srozumitelně selže, ne pád/zaseknutí.
6. **`start.sh`/`stop.sh`** ověřeny naostro: spuštění na pozadí (PID do `zvukcz.pid`, log do `zvukcz.log`/`zvukcz.err.log`), ochrana proti dvojitému spuštění (`ZvukCZ uz bezi`), čisté zastavení i úklid po already-exited procesu (`stop.sh` po pádu appky správně smaže `zvukcz.pid` a nehlásí chybu).

### Co se NEOTESTOVALO (chybí aktivní desktop session)
Živé zachytávání systémového zvuku (nalezení `.monitor` zařízení + reálný přepis mluveného slova) nejde otestovat jako root přes SSH bez přihlášeného uživatele - PipeWire běží per-user. Uživatel zvažuje přihlásit se do GNOME session (fyzicky nebo přes `gnome-remote-desktop`, který je na stroji nainstalovaný) a pustit zvuk, aby šlo tohle dootestovat.

Testovací nasazení zůstává v `/root/zvukcz-linux-test/` na vzdáleném stroji (mimo git, jen pro účely testu).

## 34. Windows instalátor u kamaráda "nic nenainstaloval" - nalezena a opravena reálná chyba v install.ps1

Uživatel předal `ZvukCZ_Install.exe` (z `ZvukCZ1.1\dist\`) kamarádovi - výsledek: černé okno se objevilo a hned zmizelo, nic se nenainstalovalo. Kamarád má NVIDIA GPU (takže to není chybějící-GPU případ z kroku 1 instalátoru).

### Diagnóza (z reálného `zvukcz.err.log`, ne odhadem)
Uživatel poslal obsah `zvukcz.err.log` z pokusu appku spustit: `& : The term 'C:\Users\Mojmir\Zvuk to CZ\.venv\Scripts\python.exe' is not recognized...` - venv nikdy nebylo správně vytvořené, ale instalátor přesto "uspěl" (vytvořil zástupce na ploše atd.).

**Kořenová příčina** (ověřeno čtením kódu a PowerShell sémantiky, ne hádáním): `& $pythonExe -m venv ...` je volání externího `.exe`. `$ErrorActionPreference = "Stop"` na začátku `install.ps1` **nemá na externí programy žádný vliv** (platí jen pro cmdlety/terminující chyby PowerShellu) - pokud `python -m venv` na kamarádově stroji z libovolného důvodu selhal (typicky: `python` v PATH je jen zástupný stub z Microsoft Storu, ne skutečný Python - přesně tenhle problém řešil úplně první bod téhle konverzace, bod 1), skript to **potichu ignoroval** a napsal "OK" i tak. Skript pak pokračoval až do konce (vytvořil zástupce), a teprve při **spuštění appky** to spadlo na chybějícím `.venv\Scripts\python.exe`.

Druhá, spolupůsobící chyba: `Read-Host "Stiskni Enter pro konec"` uvnitř zkompilovaného `.exe` (ps2exe) občas tise selže (`try/catch` už to zachytávalo, viz bod 14 dřívější historie) - i kdyby instalátor chybu vypsal, okno by se stejně hned zavřelo, protože `Read-Host` spadl a `catch {}` neudělal nic, co by okno drželo otevřené. Přesně to viděl kamarád ("černé okno se objevilo a hned zmizelo").

### Oprava (`install.ps1`, kořen i `ZvukCZ1.1\`, zatím necommitnuto)
1. Nová funkce `Pause-Konec`: `try { Read-Host ... } catch { Start-Sleep -Seconds 15 }` - `Start-Sleep` nezávisí na stdin, takže garantovaně počká 15s, i když `Read-Host` selže. Nahrazuje všech 5 předchozích `try { Read-Host ... } catch {}` výskytů.
2. Po `python -m venv` přidána explicitní kontrola `Test-Path $venvPython` - pokud venv reálně nevzniklo, skript teď **hlasitě selže** s vysvětlující hláškou (stub z MS Storu / antivirus / málo místa) místo tichého "OK".
3. Po `pip install` přidána kontrola `$LASTEXITCODE -ne 0` se stejným vzorem (hlasité selhání místo tichého pokračování).
4. Ověřeno: PowerShell parser (`[System.Management.Automation.PSParser]::Tokenize`) potvrzuje syntaktickou správnost.

Uživatel schválil rebuild+commit (`47aba4b`) a poslal nový `.exe` kamarádovi/otestoval na dalším PC (s NVIDIA GPU) - **stejný příznak zůstal** (černé okno hned zmizelo, žádná ikona, uninstall nic nesmazal), i s touto první opravou.

## 35. Druhá vrstva stejného problému - `Find-Python` mělo vlastní tichý pád

Uživatel poslal `G:\Error.txt`:
```
2) Kontrola Pythonu...
ERROR: The running command stopped because the preference variable "ErrorActionPreference" or common parameter is set to Stop: Python nebyl nalezen; spus[ť...]
```

"Python nebyl nalezen; spusť..." je přesná česká hláška Windows pro App Execution Alias stub Pythonu z Microsoft Storu (stejný problém jako v úplně prvním bodu téhle konverzace) - potvrzuje, že testovaný stroj nemá skutečný Python, jen ten stub.

### Skutečná příčina pádu (ne jen stub samotný)
`Find-Python` volalo `& python --version 2>&1`. Sloučení stderr do výstupu (`2>&1`) u externího `.exe` v PowerShellu **zabalí každý řádek stderr jako `NativeCommandError`** - a s `$ErrorActionPreference = "Stop"` na začátku skriptu se z toho stane **neodchycená ukončující výjimka přímo uvnitř `Find-Python`**, mimo dosah opravy z bodu 34 (ta hlídala jen venv/pip, ne detekci Pythonu samotnou, a `Find-Python` byla volaná mimo `try/catch`). Skript spadl úplně na začátku kroku 2, bez jakékoliv Pause-Konec hlášky - přesně "okno se objeví a hned zmizí, nic se nenainstaluje".

### Oprava (`install.ps1`, kořen i `ZvukCZ1.1`)
1. `Find-Python`: `2>&1` → `2>$null` (zahodí stderr stubu místo jeho sloučení do chybového proudu; skutečný Python vypisuje verzi na stdout, takže detekce funguje beze změny).
2. Celé tělo skriptu (od `Write-Host "=== ..."` po finální `Pause-Konec`) obaleno do `try { ... } catch { ... }` - libovolná další neočekávaná ukončující chyba (cokoliv jsme nepředvídali) teď vypíše hlášku a zavolá `Pause-Konec` místo tichého/okamžitého zavření okna. `exit 1` uvnitř `try` bloku `catch` nespouští (potvrzeno - `exit` ukončuje proces přímo, ne přes výjimku), takže existující řízené `exit 1` větve fungují beze změny.
3. **Ověřeno lokálně bez zásahu do živé instalace**: `install.ps1` spuštěn izolovaně v dočasné složce (`powershell -File`, mimo `%USERPROFILE%\Zvuk to CZ`) - kroky 1-3 (NVIDIA RTX 4070 SUPER nalezena, reálný systémový Python nalezen přes opravenou `Find-Python`, `.venv` vytvořeno) proběhly OK, `pip install` spadl na nesouvisející problém (OSError: cesta k souboru příliš dlouhá - way kvůli hluboce zanořené testovací temp složce, ne appce) a **nová kontrola `$LASTEXITCODE` to správně zachytila a vypsala CHYBA hlášku** místo tichého pokračování - přímý důkaz, že oprava z bodu 34 funguje.
4. `ZvukCZ1.1\dist\ZvukCZ_Install.exe` přebuildován podruhé s touto opravou.

### Otevřené body
- Pořád nevíme jistě, jestli je to na obou testovaných strojích (kamarád i uživatelovo "další PC") stejná příčina (MS Store stub) - `Find-Python` teď ale i tak správně spadne do větve "Python nenalezen, instaluji přes winget", takže by to mělo fungovat samo, bez nutnosti to dál diagnostikovat, POKUD winget na těch strojích funguje.

Uživatel poté rovnou na dalším PC znovu narazil na **stejný příznak i s touto opravou** - "Nenalezen Python: spust..." a hned poté "Stiskni Enter pro konec" (potvrzuje, že `try/catch` teď aspoň drží okno otevřené - pokrok), ale root cause zůstal. Uživatel se rozhodl (po nabídnuté bezpečnější alternativě - dočasně schovat Python jen přes PATH) přesto **odinstalovat Python naostro na vývojovém stroji** a testovat rovnou tady, at se to nemusí přenášet flashkou na vedlejší PC.

## 36. Uninstall otestován naostro + nalezena a opravena TŘETÍ vrstva stejného problému (`2>$null` sám o sobě nestačí)

Na explicitní pokyn uživatele: nejdřív otestován `uninstall.bat` naostro na živé instalaci (`%USERPROFILE%\Zvuk to CZ` na vývojovém stroji) - instalovaná kopie byla ze staršího instalátoru bez `uninstall.bat`/`uninstall_helper.ps1` (ty přibyly až po tomhle reálném installu), doplněny ručně ze zdrojáku, pak spuštěno naostro (`echo ano | .\uninstall.bat`).

### Nalezena reálná chyba č. 3: `uninstall_helper.ps1` mazání složky nespolehlivé
Zástupce na ploše se smazal OK, ale **složka se nesmazala celá** - `.venv` zmizelo, ale zbylo 13 souborů (`.py`, `.ps1`, `.bat`, logy). `Remove-Item -Recurse -Force -ErrorAction SilentlyContinue` na řádku 35 dělal jen **jeden pokus** po pevných 2s - pokud v tu chvíli byl nějaký soubor krátkodobě zamčený (uvolňování handlů po právě zastaveném procesu, nebo krátké "podívání" antiviru), `-ErrorAction SilentlyContinue` chybu potichu spolkl a zbytek zůstal ležet. Ověřeno manuálním opakováním `Remove-Item` o pár vteřin později - prošlo bez chyby, potvrzuje transientní zámek, ne trvalý problém.

**Oprava**: `uninstall_helper.ps1` (kořen i `ZvukCZ1.1`) - mazání teď zkouší opakovaně (15× po 1s), a pokud selže úplně, zapíše chybu do `%TEMP%\zvukcz_uninstall_error.log` místo tichého zmizení. **Ověřeno izolovaným testem** (soubor uměle zamčený na pozadí 4s, starý kód by selhal po 2s, nový kód 3× neúspěšně zkusil a pak uspěl po uvolnění zámku - přesně reprodukuje a řeší pozorovanou chybu).

### Nalezena reálná chyba č. 4 (skutečná příčina bodů 34-35, ne jen symptom): `2>$null` sám o sobě NESTAČÍ
Po odinstalaci Pythonu (`winget uninstall --id Python.Python.3.13`) se stroj dostal do přesně stejného stavu jako testovací PC (`python` resolvuje jen na MS Store stub). Spuštění opraveného `install.ps1` (z bodu 34) **stále padalo** - ale teď aspoň čistě přes nový `try/catch` s hláškou "Python nebyl nalezen; spus...".

Přesná diagnóza (izolovanými testy přímo v PowerShellu, ne odhadem):
- `2>&1` I `2>$null` na externím `.exe` **oba** způsobí, že PowerShell zabalí každý řádek stderr jako `NativeCommandError` - **nezáleží na tom, KAM se stderr přesměruje**, jde o samotný akt přesměrování stderr operátorem `2>`. S `$ErrorActionPreference = "Stop"` se z toho vždy stane neodchycená ukončující výjimka.
- Bez JAKÉHOKOLIV přesměrování (`& python --version` bez `2>...`) stderr prostě propadne do konzole normálně, bez pádu - ale pak by se ošklivá hláška stubu zobrazovala uživateli přímo.
- **Jediné spolehlivé řešení**: `try { $ver = & python --version 2>$null } catch { $ver = "" }` - `try/catch` přímo kolem volání, `2>$null` navíc jen pro potlačení textu v běžném (nespadlém) případě.

**Oprava** (`install.ps1`, kořen i `ZvukCZ1.1`): `Find-Python` obalen do `try/catch`. Stejný vzor preventivně přidán i do kroku 5 (ověření GPU), který měl identický `2>$null` bez try/catch (latentní riziko, nebyl přímo pozorován jako padající, ale mechanismus je stejný).

### Ověřeno naostro end-to-end (na vývojovém stroji, Python fakt odinstalovaný)
1. Izolovaný test v temp složce: krok 2 teď správně vypsal "Python nenalezen, instaluji pres winget..." **a `winget` automaticky stáhl a nainstaloval skutečný Python 3.13.15** - celá auto-recovery větev funguje. Pád na kroku 4 (`pip install`) byl znovu jen kvůli mé vlastní hluboce zanořené temp cestě (Windows Long Path limit), ne appce - a i tak správně zachyceno a nahlášeno.
2. **Plný reálný běh** přímo zkompilovaného `ZvukCZ1.1\dist\ZvukCZ_Install.exe` (přebuildován potřetí) do skutečné cílové složky (`%USERPROFILE%\Zvuk to CZ`) - proběhlo **kompletně bez chyby**: Python auto-nainstalován, `.venv` vytvořeno, všechny balíčky nainstalovány, GPU ověřeno (1 zařízení), zástupce na ploše vytvořen.
3. Appka spuštěna přes `start.bat` - `zvukcz.log` potvrzuje: našla loopback zařízení, model načten, proces běží. DeepL klíč ručně dokopírován z kořenové zálohy (needošel při neinteraktivním testu), appka je na vývojovém stroji zpátky ve stejném funkčním stavu jako před testováním.

### Otevřené body
- Nevíme jistě, že kamarádův/uživatelův "další PC" mají STEJNOU příčinu (MS Store stub) jako tenhle test, ale mechanismus opravy (`try/catch` kolem `Find-Python`) řeší libovolnou variantu selhání detekce Pythonu, ne jen tenhle konkrétní scénář.
- Zatím necommitnuto (čeká se na pokyn uživatele) - `install.ps1` (2. kolo oprav), `uninstall_helper.ps1` (retry logika), `ZvukCZ1.1\dist\ZvukCZ_Install.exe` (3. rebuild).

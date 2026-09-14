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

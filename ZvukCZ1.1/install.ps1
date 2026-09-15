# Instalator - Mumble do CZ (NVIDIA GPU verze)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$versionFile = Join-Path $root "VERSION"
$version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "?" }

# Read-Host uvnitr zkompilovaneho .exe (ps2exe) obcas tise selze (chybi
# interaktivni konzole) - bez fallbacku by se okno zavrelo driv, nez si
# clovek stihne precist chybovou hlasku. Start-Sleep na stdin nezavisi,
# takze zarucene pocka, i kdyz Read-Host spadne.
function Pause-Konec {
    try { Read-Host "Stiskni Enter pro konec" } catch { Start-Sleep -Seconds 15 }
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Find-Python {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) {
        # Jakakoliv explicitni presmerovani stderr (2>&1, 2>$null, ...) na
        # externim .exe zabali KAZDY radek stderr jako NativeCommandError -
        # a s $ErrorActionPreference = "Stop" se z toho stane neodchycena
        # ukoncujici vyjimka, bez ohledu na to, kam presmerovani miri (proste
        # 2>$null NESTACI samo o sobe, overeno testem). Presne tohle se stalo
        # s MS Store "python" stubem (pise na stderr "Python nebyl
        # nalezen..."), skript spadl uplne na zacatku bez jakekoliv hlasky.
        # Reseni: try/catch primo kolem volani.
        try {
            $ver = & python --version 2>$null
        } catch {
            $ver = ""
        }
        if ($ver -match "Python 3\.(1[1-9]|[2-9]\d)") { return $cmd.Source }
    }
    return $null
}

try {

Write-Host "=== Mumble do CZ - instalace v$version (NVIDIA GPU) ===" -ForegroundColor Cyan
Write-Host ""

# 1) NVIDIA GPU
Write-Host "1) Kontrola NVIDIA graficke karty..."
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
if (-not $gpu) {
    Write-Host "   V PC nebyla nalezena NVIDIA graficka karta. Tento instalator je jen pro NVIDIA GPU verzi." -ForegroundColor Red
    Pause-Konec
    exit 1
}
Write-Host "   OK: $($gpu.Name)" -ForegroundColor Green

# 2) Python
Write-Host ""
Write-Host "2) Kontrola Pythonu..."
$pythonExe = Find-Python
if (-not $pythonExe) {
    Write-Host "   Python nenalezen, instaluji pres winget (Python 3.13)..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "   winget neni k dispozici. Nainstaluj Python rucne z https://python.org a spust instalaci znovu." -ForegroundColor Red
        Pause-Konec
        exit 1
    }
    winget install --id Python.Python.3.13 -e --source winget --accept-package-agreements --accept-source-agreements
    Refresh-Path
    $pythonExe = Find-Python
    if (-not $pythonExe) {
        Write-Host "   Python se nepodarilo najit ani po instalaci. Zavri toto okno, otevri nove PowerShell okno a spust install.bat znovu." -ForegroundColor Red
        Pause-Konec
        exit 1
    }
}
Write-Host "   OK: $pythonExe" -ForegroundColor Green

# 3) venv
Write-Host ""
Write-Host "3) Virtualni prostredi (.venv)..."
$venvPython = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    & $pythonExe -m venv (Join-Path $root ".venv")
}
# & na externi .exe negeneruje terminujici chybu ani s $ErrorActionPreference
# = Stop - bez tehle kontroly by skript tise pokracoval dal i po neuspesnem
# vytvoreni venv (presne tohle se stalo - viz zvukcz.err.log s hlaskou
# "python.exe is not recognized" pri prvnim spusteni appky).
if (-not (Test-Path $venvPython)) {
    Write-Host "   CHYBA: vytvoreni .venv selhalo (chybi $venvPython)." -ForegroundColor Red
    Write-Host "   Nejcastejsi priciny: 'python' v PATH je jen zastupny stub z Microsoft" -ForegroundColor Red
    Write-Host "   Storu (nejde o skutecny Python), antivirus zablokoval zapis, nebo malo" -ForegroundColor Red
    Write-Host "   mista na disku. Zkontroluj 'python --version' v bezne otevrenem" -ForegroundColor Red
    Write-Host "   PowerShellu a spust instalaci znovu." -ForegroundColor Red
    Pause-Konec
    exit 1
}
Write-Host "   OK" -ForegroundColor Green

# 4) balicky
Write-Host ""
Write-Host "4) Instalace balicku (muze chvili trvat, stahuji se i CUDA knihovny)..."
& $venvPython -m pip install --upgrade pip --quiet
& $venvPython -m pip install -r (Join-Path $root "requirements.txt")
if ($LASTEXITCODE -ne 0) {
    Write-Host "   CHYBA: instalace balicku selhala (pip skoncil s chybou). Zkontroluj" -ForegroundColor Red
    Write-Host "   pripojeni k internetu a spust instalaci znovu." -ForegroundColor Red
    Pause-Konec
    exit 1
}
Write-Host "   OK" -ForegroundColor Green

# 5) over GPU
Write-Host ""
Write-Host "5) Overeni GPU..."
# try/catch ze stejneho duvodu jako u Find-Python - 2>$null samo o sobe
# nestaci, kdyby ctranslate2 pri importu neco vypsal na stderr.
try {
    $cudaCount = & $venvPython -c "import ctranslate2; print(ctranslate2.get_cuda_device_count())" 2>$null
} catch {
    $cudaCount = ""
}
if ($cudaCount -match "^\d+$" -and [int]$cudaCount -ge 1) {
    Write-Host "   OK, GPU pripraveno ($cudaCount zarizeni)" -ForegroundColor Green
} else {
    Write-Host "   POZOR: GPU se nepodarilo overit, zkontroluj ovladace NVIDIA karty." -ForegroundColor Yellow
}

# 6) DeepL klic
Write-Host ""
$keyFile = Join-Path $root "deepl_key.txt"
if (Test-Path $keyFile) {
    Write-Host "6) DeepL klic uz je nastaveny, preskakuji."
} else {
    Write-Host "6) DeepL API klic (volitelne - bez nej skript jen prepisuje anglicky, neprekada)."
    Write-Host "   Zdarma (Free tier, 500 000 znaku/mesic): https://www.deepl.com/pro-api" -ForegroundColor Cyan
    Write-Host "   Podrobny navod viz README.md."
    $key = $null
    try { $key = Read-Host "   Zadej DeepL API klic (nebo nech prazdne a stiskni Enter)" } catch { $key = $null }
    if ($key) {
        Set-Content -Path $keyFile -Value $key -NoNewline
        Write-Host "   Ulozeno." -ForegroundColor Green
    } else {
        Write-Host "   Preskoceno, muzes doplnit pozdeji do souboru deepl_key.txt (viz README.md)." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Hotovo! ===" -ForegroundColor Cyan
Write-Host "Spusteni: start.bat"
Write-Host "Zastaveni: stop.bat"
Write-Host "Odinstalace: uninstall.bat"
Pause-Konec

}
catch {
    Write-Host ""
    Write-Host "NEOCEKAVANA CHYBA:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Pause-Konec
    exit 1
}

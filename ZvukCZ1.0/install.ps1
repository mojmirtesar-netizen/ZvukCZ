# Instalator - Mumble do CZ (NVIDIA GPU verze)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Find-Python {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) {
        $ver = & python --version 2>&1
        if ($ver -match "Python 3\.(1[1-9]|[2-9]\d)") { return $cmd.Source }
    }
    return $null
}

Write-Host "=== Mumble do CZ - instalace (NVIDIA GPU) ===" -ForegroundColor Cyan
Write-Host ""

# 1) NVIDIA GPU
Write-Host "1) Kontrola NVIDIA graficke karty..."
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
if (-not $gpu) {
    Write-Host "   V PC nebyla nalezena NVIDIA graficka karta. Tento instalator je jen pro NVIDIA GPU verzi." -ForegroundColor Red
    try { Read-Host "Stiskni Enter pro konec" } catch {}
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
        try { Read-Host "Stiskni Enter pro konec" } catch {}
        exit 1
    }
    winget install --id Python.Python.3.13 -e --source winget --accept-package-agreements --accept-source-agreements
    Refresh-Path
    $pythonExe = Find-Python
    if (-not $pythonExe) {
        Write-Host "   Python se nepodarilo najit ani po instalaci. Zavri toto okno, otevri nove PowerShell okno a spust install.bat znovu." -ForegroundColor Red
        try { Read-Host "Stiskni Enter pro konec" } catch {}
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
Write-Host "   OK" -ForegroundColor Green

# 4) balicky
Write-Host ""
Write-Host "4) Instalace balicku (muze chvili trvat, stahuji se i CUDA knihovny)..."
& $venvPython -m pip install --upgrade pip --quiet
& $venvPython -m pip install -r (Join-Path $root "requirements.txt")
Write-Host "   OK" -ForegroundColor Green

# 5) over GPU
Write-Host ""
Write-Host "5) Overeni GPU..."
$cudaCount = & $venvPython -c "import ctranslate2; print(ctranslate2.get_cuda_device_count())" 2>$null
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
    $key = $null
    try { $key = Read-Host "   Zadej DeepL API klic (nebo nech prazdne a stiskni Enter)" } catch { $key = $null }
    if ($key) {
        Set-Content -Path $keyFile -Value $key -NoNewline
        Write-Host "   Ulozeno." -ForegroundColor Green
    } else {
        Write-Host "   Preskoceno, muzes doplnit pozdeji do souboru deepl_key.txt." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Hotovo! ===" -ForegroundColor Cyan
Write-Host "Spusteni: start.bat"
Write-Host "Zastaveni: stop.bat"
try { Read-Host "Stiskni Enter pro konec" } catch {}

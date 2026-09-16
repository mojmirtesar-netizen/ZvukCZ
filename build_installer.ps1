# Sestavi dva spustitelne soubory bez konzole (ps2exe -NoConsole):
#   ZvukCZ_Uninstall.exe - zkompilovany z uninstall_gui.ps1, vlozeny do
#                           instalatoru jako jeden z rozbalovanych souboru
#   ZvukCZ_Install.exe   - install_gui.ps1 + vsechny potrebne soubory (base64)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$distDir = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# Kazdy rebuild automaticky zvysi patch cislo (X.Y.Z -> X.Y.Z+1), aby se dalo
# poznat, kterou verzi kdo ma nainstalovanou, bez nutnosti to hlidat rucne.
$versionFile = Join-Path $root "VERSION"
$versionParts = (Get-Content $versionFile -Raw).Trim().Split(".")
$versionParts[2] = [string]([int]$versionParts[2] + 1)
$version = $versionParts -join "."
Set-Content -Path $versionFile -Value $version -NoNewline
Write-Host "Verze: $version"

Import-Module ps2exe
$iconFile = Join-Path $root "zvukcz.ico"

Write-Host ""
Write-Host "Kompiluji ZvukCZ_Uninstall.exe..."
$uninstallExe = Join-Path $distDir "ZvukCZ_Uninstall.exe"
Invoke-PS2EXE -InputFile (Join-Path $root "uninstall_gui.ps1") `
    -OutputFile $uninstallExe `
    -IconFile $iconFile `
    -Title "Mumble do CZ - odinstalace" `
    -Version $version `
    -Product "ZvukCZ" `
    -NoConsole:$true `
    -RequireAdmin:$false

# Soubory, ktere ZvukCZ_Install.exe pri spusteni rozbali do cilove slozky.
# ZvukCZ_Uninstall.exe se bere uz zkompilovany (z distDir), aby odinstalace
# taky bezela jako okno bez konzole - viz vyse.
$filesToEmbed = @{
    "loopback_translator.py" = Join-Path $root "loopback_translator.py"
    "run.ps1"                = Join-Path $root "run.ps1"
    "start.bat"               = Join-Path $root "start.bat"
    "stop.bat"                = Join-Path $root "stop.bat"
    "start_helper.ps1"        = Join-Path $root "start_helper.ps1"
    "stop_helper.ps1"         = Join-Path $root "stop_helper.ps1"
    "requirements.txt"        = Join-Path $root "requirements.txt"
    "zvukcz.ico"              = $iconFile
    "README.md"                = Join-Path $root "README.md"
    "VERSION"                  = $versionFile
    "ZvukCZ_Uninstall.exe"     = $uninstallExe
}

Write-Host ""
Write-Host "Baleni souboru..."
$embedded = @{}
foreach ($name in $filesToEmbed.Keys) {
    $bytes = [System.IO.File]::ReadAllBytes($filesToEmbed[$name])
    $embedded[$name] = [System.Convert]::ToBase64String($bytes)
    Write-Host "   + $name ($($bytes.Length) B)"
}

# --- preambule: vlozena verze + vlozene soubory, pak cely install_gui.ps1 ---
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('$ErrorActionPreference = "Stop"')
[void]$sb.AppendLine("`$Global:EmbeddedVersion = '$version'")
[void]$sb.AppendLine('$Global:EmbeddedFiles = @{')
foreach ($k in $embedded.Keys) {
    [void]$sb.AppendLine("    '$k' = '$($embedded[$k])'")
}
[void]$sb.AppendLine('}')
[void]$sb.AppendLine((Get-Content (Join-Path $root "install_gui.ps1") -Raw))

$generatedPs1 = Join-Path $distDir "ZvukCZ_Install_generated.ps1"
Set-Content -Path $generatedPs1 -Value $sb.ToString() -Encoding UTF8

Write-Host ""
Write-Host "Kompiluji ZvukCZ_Install.exe..."
Invoke-PS2EXE -InputFile $generatedPs1 `
    -OutputFile (Join-Path $distDir "ZvukCZ_Install.exe") `
    -IconFile $iconFile `
    -Title "Mumble do CZ - instalace" `
    -Version $version `
    -Product "ZvukCZ" `
    -NoConsole:$true `
    -RequireAdmin:$false

Write-Host ""
Write-Host "Hotovo:" -ForegroundColor Cyan
Write-Host "  $(Join-Path $distDir 'ZvukCZ_Install.exe')"
Write-Host "  $uninstallExe"

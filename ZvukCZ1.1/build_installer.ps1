# Sestavi jeden spustitelny ZvukCZ_Install.exe, ktery v sobe nese vsechny
# potrebne soubory a pri spusteni je rozbali + provede celou instalaci.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$distDir = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$filesToEmbed = @(
    "loopback_translator.py",
    "run.ps1",
    "start.bat",
    "stop.bat",
    "start_helper.ps1",
    "stop_helper.ps1",
    "uninstall.bat",
    "uninstall_helper.ps1",
    "requirements.txt",
    "zvukcz.ico"
)

Write-Host "Baleni souboru..."
$embedded = @{}
foreach ($f in $filesToEmbed) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $root $f))
    $embedded[$f] = [System.Convert]::ToBase64String($bytes)
    Write-Host "   + $f ($($bytes.Length) B)"
}

# --- preambule: cilova slozka + rozbaleni vlozenych souboru ---
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('$ErrorActionPreference = "Stop"')
[void]$sb.AppendLine('$targetDir = Join-Path $env:USERPROFILE "Zvuk to CZ"')
[void]$sb.AppendLine('New-Item -ItemType Directory -Force -Path $targetDir | Out-Null')
[void]$sb.AppendLine('Write-Host "=== Mumble do CZ - instalace (NVIDIA GPU) ===" -ForegroundColor Cyan')
[void]$sb.AppendLine('Write-Host ""')
[void]$sb.AppendLine('Write-Host "Cilova slozka: $targetDir"')
[void]$sb.AppendLine('Write-Host ""')
[void]$sb.AppendLine('Write-Host "0) Rozbaluji soubory..."')
[void]$sb.AppendLine('$files = @{')
foreach ($k in $embedded.Keys) {
    [void]$sb.AppendLine("    '$k' = '$($embedded[$k])'")
}
[void]$sb.AppendLine('}')
[void]$sb.AppendLine(@'
foreach ($name in $files.Keys) {
    $bytes = [System.Convert]::FromBase64String($files[$name])
    [System.IO.File]::WriteAllBytes((Join-Path $targetDir $name), $bytes)
}
Write-Host "   OK" -ForegroundColor Green
Write-Host ""
'@)

# --- zbytek instalacni logiky prevzaty z install.ps1, $root -> $targetDir ---
$installLogic = Get-Content (Join-Path $root "install.ps1") -Raw
$installLogic = $installLogic -replace '(?m)^\$root = \$PSScriptRoot\r?\n', ''
$installLogic = $installLogic -replace '(?m)^# Instalator.*\r?\n', ''
$installLogic = $installLogic -replace '\$root\b', '$targetDir'
[void]$sb.AppendLine($installLogic)

# --- zastupce na plose ---
[void]$sb.AppendLine(@'
$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "ZvukCZ.lnk"
try {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($shortcutPath)
    $sc.TargetPath = "powershell.exe"
    $sc.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$targetDir\start_helper.ps1`""
    $sc.WorkingDirectory = $targetDir
    $sc.IconLocation = "$targetDir\zvukcz.ico"
    $sc.Description = "ZvukCZ - preklad systemoveho zvuku do titulku"
    $sc.Save()
    Write-Host "Zastupce na plose vytvoren: $shortcutPath" -ForegroundColor Green
} catch {
    Write-Host "Zastupce na plose se nepodarilo vytvorit: $_" -ForegroundColor Yellow
}
'@)

[void]$sb.AppendLine('Write-Host "Slozka: $targetDir"')

$generatedPs1 = Join-Path $distDir "ZvukCZ_Install_generated.ps1"
Set-Content -Path $generatedPs1 -Value $sb.ToString() -Encoding UTF8

Write-Host ""
Write-Host "Kompiluji do .exe (ps2exe)..."
Import-Module ps2exe
Invoke-PS2EXE -InputFile $generatedPs1 `
    -OutputFile (Join-Path $distDir "ZvukCZ_Install.exe") `
    -Title "Mumble do CZ - instalace" `
    -NoConsole:$false `
    -RequireAdmin:$false

Write-Host ""
Write-Host "Hotovo: $(Join-Path $distDir 'ZvukCZ_Install.exe')" -ForegroundColor Cyan

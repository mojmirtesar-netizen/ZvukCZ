$targetDir = $PSScriptRoot

Write-Host "=== Odinstalace ZvukCZ ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tohle smaze:"
Write-Host "  - bezici program (pokud bezi)"
Write-Host "  - zastupce na plose"
Write-Host "  - celou slozku: $targetDir"
Write-Host ""

$confirm = Read-Host "Opravdu odinstalovat? (napis 'ano' pro potvrzeni)"
if ($confirm -ne "ano") {
    Write-Host "Zruseno, nic se nesmazalo."
    exit
}

$stopHelper = Join-Path $targetDir "stop_helper.ps1"
if (Test-Path $stopHelper) {
    Write-Host "Zastavuji bezici program (pokud bezi)..."
    try { powershell -NoProfile -ExecutionPolicy Bypass -File $stopHelper | Out-Null } catch {}
}

$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "ZvukCZ.lnk"
if (Test-Path $desktopShortcut) {
    Remove-Item $desktopShortcut -Force -ErrorAction SilentlyContinue
    Write-Host "Zastupce na plose odstranen."
}

# Tenhle skript bezi ZEVNITR mazane slozky, takze slozku nemuze smazat sam
# sebe primo - spusti se oddeleny proces mimo slozku (v %TEMP%), ktery po
# kratke prodleve (az tenhle skript skonci a uvolni soubor) slozku smaze.
$tempScript = Join-Path $env:TEMP "zvukcz_uninstall_$([guid]::NewGuid().ToString('N')).ps1"
$deleterScript = @"
Start-Sleep -Seconds 2
Remove-Item -LiteralPath '$targetDir' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath '$tempScript' -Force -ErrorAction SilentlyContinue
"@
Set-Content -Path $tempScript -Value $deleterScript -Encoding UTF8
Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -WindowStyle Hidden

Write-Host ""
Write-Host "Hotovo - slozka se smaze za pár vterin na pozadi. Toto okno se zavre." -ForegroundColor Green

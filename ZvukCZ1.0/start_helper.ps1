$pidFile = Join-Path $PSScriptRoot "zvukcz.pid"

if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile
    if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
        Write-Host "Skript uz bezi (PID $oldPid). Pro restart nejdriv spust stop.bat."
        exit
    }
}

$runPs1 = Join-Path $PSScriptRoot "run.ps1"
$argList = "-NoExit -ExecutionPolicy Bypass -File `"$runPs1`""
$proc = Start-Process -FilePath "powershell" -ArgumentList $argList -PassThru

$proc.Id | Out-File -Encoding ascii $pidFile
Write-Host "Spusteno (PID $($proc.Id))."

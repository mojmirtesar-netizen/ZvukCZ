$pidFile = Join-Path $PSScriptRoot "zvukcz.pid"

if (-not (Test-Path $pidFile)) {
    Write-Host "Skript neni spusteny (chybi PID soubor)."
    exit
}

$targetPid = Get-Content $pidFile

if ($targetPid -and (Get-Process -Id $targetPid -ErrorAction SilentlyContinue)) {
    # najdi cely strom potomku (python.exe umi zalozit dalsi vnoreny proces)
    $allProcs = Get-CimInstance Win32_Process
    $toKill = [System.Collections.Generic.List[int]]::new()
    $frontier = [System.Collections.Generic.List[int]]::new()
    $frontier.Add([int]$targetPid)
    while ($frontier.Count -gt 0) {
        $current = $frontier[0]
        $frontier.RemoveAt(0)
        $toKill.Add($current)
        $allProcs | Where-Object { $_.ParentProcessId -eq $current } | ForEach-Object {
            $frontier.Add([int]$_.ProcessId)
        }
    }
    # nejdriv nejhlubsi potomky, pak rodice
    [array]::Reverse($toKill)
    foreach ($procId in $toKill) {
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Zastaveno (PID $targetPid + $($toKill.Count - 1) potomku)."
} else {
    Write-Host "Skript uz nebezel."
}

Remove-Item $pidFile -ErrorAction SilentlyContinue

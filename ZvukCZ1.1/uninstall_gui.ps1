$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# $PSScriptRoot je uvnitr zkompilovaneho ZvukCZ_Uninstall.exe (ps2exe)
# nespolehlivy - v realnem testu vysel jako prazdny retezec (ne $null),
# takze kazdy Join-Path/Test-Path/Get-Content s nim spadl na "Cannot bind
# argument to parameter 'Path' because it is an empty string." Cesta k
# bezicimu .exe pres MainModule.FileName funguje spolehlive v obou pripadech
# (zkompilovane i pri lokalnim spusteni .ps1, kdy $PSScriptRoot funguje
# normalne).
$targetDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }

# Lehka verze Invoke-Native pro rychlou synchronni kontrolu na UI vlakne
# (zda je Python nainstalovany pres winget) - stejny duvod jako v
# install_gui.ps1: '&' na externi konzolovou aplikaci z prostredi bez
# konzole (ps2exe -NoConsole) umi na kratko vyblesknout oknem.
function Invoke-NativeQuick {
    param([string]$FilePath, [string[]]$CmdArgs)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($CmdArgs | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    try {
        [void]$proc.Start()
        [void]$proc.StandardOutput.ReadToEnd()
        [void]$proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return $proc.ExitCode
    } catch {
        return -1
    }
}

# --- GUI zaklad ---------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Mumble do CZ - odinstalace"
$form.ClientSize = New-Object System.Drawing.Size(560, 360)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
try {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
} catch {}

$header = New-Object System.Windows.Forms.Panel
$header.Size = New-Object System.Drawing.Size(560, 64)
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.BackColor = [System.Drawing.Color]::FromArgb(0, 99, 143)
$form.Controls.Add($header)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Mumble do CZ"
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 10)
$lblTitle.AutoSize = $true
$header.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text = "Odinstalace"
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(210, 230, 240)
$lblSubtitle.Location = New-Object System.Drawing.Point(22, 40)
$lblSubtitle.AutoSize = $true
$header.Controls.Add($lblSubtitle)

$content = New-Object System.Windows.Forms.Panel
$content.Location = New-Object System.Drawing.Point(0, 64)
$content.Size = New-Object System.Drawing.Size(560, 240)
$form.Controls.Add($content)

$separator = New-Object System.Windows.Forms.Panel
$separator.Location = New-Object System.Drawing.Point(0, 304)
$separator.Size = New-Object System.Drawing.Size(560, 1)
$separator.BackColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$form.Controls.Add($separator)

$footer = New-Object System.Windows.Forms.Panel
$footer.Location = New-Object System.Drawing.Point(0, 305)
$footer.Size = New-Object System.Drawing.Size(560, 55)
$form.Controls.Add($footer)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Zrusit"
$btnCancel.Size = New-Object System.Drawing.Size(90, 28)
$btnCancel.Location = New-Object System.Drawing.Point(450, 14)
$footer.Controls.Add($btnCancel)

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = "Odinstalovat"
$btnNext.Size = New-Object System.Drawing.Size(110, 28)
$btnNext.Location = New-Object System.Drawing.Point(330, 14)
$footer.Controls.Add($btnNext)

$form.AcceptButton = $btnNext
$form.CancelButton = $btnCancel

function New-Page {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point(0, 0)
    $p.Size = New-Object System.Drawing.Size(560, 240)
    $p.Visible = $false
    $content.Controls.Add($p)
    return $p
}

# --- stranka 0: potvrzeni ---------------------------------------------------

$pnlConfirm = New-Page
$lblConfirm = New-Object System.Windows.Forms.Label
$lblConfirm.Location = New-Object System.Drawing.Point(24, 16)
$lblConfirm.Size = New-Object System.Drawing.Size(510, 110)
$lblConfirm.Text = "Tohle odstrani:`n  - bezici program (pokud bezi)`n  - zastupce na plose`n  - celou slozku: $targetDir"
$pnlConfirm.Controls.Add($lblConfirm)

$chkPython = New-Object System.Windows.Forms.CheckBox
$chkPython.Location = New-Object System.Drawing.Point(24, 130)
$chkPython.Size = New-Object System.Drawing.Size(510, 40)
$chkPython.Text = "Odinstalovat i Python 3.13 (nainstaloval ho tento instalator). POZOR: nezaskrtavej, pokud Python pouzivas i pro neco jineho."
$pnlConfirm.Controls.Add($chkPython)

$script:pythonFound = (Invoke-NativeQuick -FilePath "winget" -CmdArgs @("list", "--id", "Python.Python.3.13", "-e", "--accept-source-agreements")) -eq 0
$chkPython.Visible = $script:pythonFound
if (-not $script:pythonFound) {
    $lblNoPython = New-Object System.Windows.Forms.Label
    $lblNoPython.Location = New-Object System.Drawing.Point(24, 130)
    $lblNoPython.Size = New-Object System.Drawing.Size(510, 20)
    $lblNoPython.ForeColor = [System.Drawing.Color]::Gray
    $lblNoPython.Text = "(Python 3.13 pres winget nenalezen, nabidka odinstalace se neukazuje.)"
    $pnlConfirm.Controls.Add($lblNoPython)
}

# --- stranka 1: prubeh -----------------------------------------------------

$pnlProgress = New-Page
$lblStep = New-Object System.Windows.Forms.Label
$lblStep.Location = New-Object System.Drawing.Point(24, 16)
$lblStep.Size = New-Object System.Drawing.Size(510, 20)
$lblStep.Text = "Pripravuji odinstalaci..."
$pnlProgress.Controls.Add($lblStep)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(24, 40)
$progressBar.Size = New-Object System.Drawing.Size(510, 20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$pnlProgress.Controls.Add($progressBar)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(24, 70)
$txtLog.Size = New-Object System.Drawing.Size(510, 160)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$txtLog.BackColor = [System.Drawing.Color]::White
$pnlProgress.Controls.Add($txtLog)

# --- stranka 2: hotovo ------------------------------------------------------

$pnlFinish = New-Page
$lblFinishTitle = New-Object System.Windows.Forms.Label
$lblFinishTitle.Location = New-Object System.Drawing.Point(24, 16)
$lblFinishTitle.Size = New-Object System.Drawing.Size(510, 30)
$lblFinishTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblFinishTitle.Text = "Hotovo"
$pnlFinish.Controls.Add($lblFinishTitle)

$lblFinishBody = New-Object System.Windows.Forms.Label
$lblFinishBody.Location = New-Object System.Drawing.Point(24, 55)
$lblFinishBody.Size = New-Object System.Drawing.Size(510, 140)
$lblFinishBody.Text = "Program byl radne zastaven a zastupce odstranen.`n`nSamotna slozka ($targetDir) se maze na pozadi - muze to trvat az par minut, pokud ji zrovna kontroluje antivirus. Az se to podari, dostanes hlasku s potvrzenim (nebo s cestou k rucnimu smazani, kdyby se to nepovedlo).`n`nToto okno muzes zavrit."
$pnlFinish.Controls.Add($lblFinishBody)

# --- navigace ---------------------------------------------------------------

$panels = @($pnlConfirm, $pnlProgress, $pnlFinish)
$script:currentPage = 0
$script:uninstallRunning = $false
$script:uninstallDone = $false

function Show-Page($idx) {
    foreach ($p in $panels) { $p.Visible = $false }
    $panels[$idx].Visible = $true
    $script:currentPage = $idx
    switch ($idx) {
        0 {
            $btnNext.Text = "Odinstalovat"
            $btnNext.Visible = $true
            $btnNext.Enabled = $true
            $btnCancel.Text = "Zrusit"
        }
        1 {
            $btnNext.Visible = $false
            $btnCancel.Text = "Zrusit"
        }
        2 {
            $btnNext.Visible = $false
            $btnCancel.Text = "Zavrit"
        }
    }
}

# --- odinstalacni logika (bezi na pozadi v samostatnem runspace) -----------

$uninstallSteps = {
    param($targetDir, $uninstallPython, $sync)

    function Log($msg) { [void]$sync.Log.Add([string]$msg) }
    function Step($pct, $text) { $sync.Progress = $pct; $sync.CurrentStep = $text; Log $text }

    function Invoke-Native {
        param([string]$FilePath, [string[]]$CmdArgs, [switch]$Silent)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        $psi.Arguments = ($CmdArgs | ForEach-Object {
            if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        }) -join ' '
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $outLines = New-Object System.Collections.Generic.List[string]
        try {
            [void]$proc.Start()
        } catch {
            return [pscustomobject]@{ ExitCode = -1; Output = $outLines; Error = $_.Exception.Message }
        }
        $errTask = $proc.StandardError.ReadToEndAsync()
        while ($true) {
            $line = $proc.StandardOutput.ReadLine()
            if ($null -eq $line) { break }
            $outLines.Add($line)
            if (-not $Silent) { Log "   $line" }
        }
        $proc.WaitForExit()
        $errText = $errTask.GetAwaiter().GetResult()
        if (-not $Silent -and $errText) {
            foreach ($l in ($errText -split "`r?`n")) { if ($l) { Log "   $l" } }
        }
        return [pscustomobject]@{ ExitCode = $proc.ExitCode; Output = $outLines; Error = $errText }
    }

    try {
        Step 10 "Zastavuji bezici program (pokud bezi)..."
        $pidFile = Join-Path $targetDir "zvukcz.pid"
        if (Test-Path $pidFile) {
            $targetPid = Get-Content $pidFile
            if ($targetPid -and (Get-Process -Id $targetPid -ErrorAction SilentlyContinue)) {
                $allProcs = Get-CimInstance Win32_Process
                $toKill = [System.Collections.Generic.List[int]]::new()
                $frontier = [System.Collections.Generic.List[int]]::new()
                $frontier.Add([int]$targetPid)
                while ($frontier.Count -gt 0) {
                    $current = $frontier[0]
                    $frontier.RemoveAt(0)
                    $toKill.Add($current)
                    $allProcs | Where-Object { $_.ParentProcessId -eq $current } | ForEach-Object { $frontier.Add([int]$_.ProcessId) }
                }
                [array]::Reverse($toKill)
                # Stop-Process jen posle signal k ukonceni a hned se vrati -
                # nečeka, az proces skutecne zmizi. U procesu s nactenymi
                # CUDA/torch knihovnami muze OS/ovladac jeste chvili po
                # "ukonceni" drzet soubory zamcene (overeno realnym testem -
                # slozka se pak nedala smazat, ale po par minutach uz sla bez
                # problemu). Wait-Process da mazaci smycce nize realnou sanci
                # zacinat az po skutecnem uvolneni handlu.
                foreach ($procId in $toKill) {
                    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                    Wait-Process -Id $procId -Timeout 30 -ErrorAction SilentlyContinue
                }
                Log "   Zastaveno (PID $targetPid + $($toKill.Count - 1) potomku)."
                # I po potvrzenem ukonceni procesu jeste NVIDIA ovladac chvili
                # uklizi CUDA kontext (mapovane soubory/DLL) - bez teto
                # prodlevy mazani slozky nize casto naráželo na "soubor je
                # pouzivan jinym procesem" (overeno realnym testem).
                Log "   Cekam na uvolneni GPU prostredku..."
                Start-Sleep -Seconds 5
            } else {
                Log "   Program uz nebezel."
            }
            Remove-Item $pidFile -ErrorAction SilentlyContinue
        } else {
            Log "   Program nebezel (chybi PID soubor)."
        }

        Step 30 "Odstranuji zastupce na plose..."
        $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "ZvukCZ.lnk"
        if (Test-Path $desktopShortcut) {
            Remove-Item $desktopShortcut -Force -ErrorAction SilentlyContinue
            Log "   OK"
        } else {
            Log "   Zastupce nenalezen, preskakuji."
        }

        if ($uninstallPython) {
            Step 50 "Odinstalovavam Python 3.13..."
            $r = Invoke-Native -FilePath "winget" -CmdArgs @("uninstall", "--id", "Python.Python.3.13", "-e", "--accept-source-agreements")
            if ($r.ExitCode -eq 0) { Log "   Python odinstalovan." } else { Log "   Odinstalace Pythonu selhala (kod $($r.ExitCode))." }
        }

        # Tenhle skript (a pripadne zkompilovany .exe) bezi ZEVNITR mazane
        # slozky, takze slozku nemuze smazat sam sebe primo - spusti se
        # oddeleny proces mimo slozku (v %TEMP%), ktery po strasi 2s a az se
        # tenhle proces ukonci, slozku smaze. Hlavni prevence pred zamknutymi
        # soubory je uz vyse (Wait-Process + prodleva na GPU cleanup) - tohle
        # okno pokusu je jen pojistka pro antivirus, ktery muze skenovat
        # velkou slozku (radove GB) desitky sekund. Viditelne potvrzeni
        # vysledku (uspech i selhani), ne jen tichy log.
        Step 90 "Pripravuji smazani slozky na pozadi..."
        $tempScript = Join-Path $env:TEMP "zvukcz_uninstall_$([guid]::NewGuid().ToString('N')).ps1"
        $deleterScript = @"
`$target = '$targetDir'
`$deleted = `$false
`$lastError = `$null
for (`$i = 0; `$i -lt 150; `$i++) {
    Start-Sleep -Seconds 2
    try {
        Remove-Item -LiteralPath `$target -Recurse -Force -ErrorAction Stop
        `$deleted = `$true
        break
    } catch {
        `$lastError = `$_
    }
}
try { Add-Type -AssemblyName System.Windows.Forms } catch {}
if (`$deleted) {
    try {
        [System.Windows.Forms.MessageBox]::Show("Slozka ZvukCZ byla uspesne smazana:``n`$target", "Odinstalace ZvukCZ dokoncena", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } catch {}
} else {
    # I po vycerpani vsech pokusu jeste jednou skutecne over, jestli slozka
    # existuje - `$lastError muze byt jen z prubezneho pokusu, zatimco mezitim
    # (napr. antivirus prave dokoncil sken) uz mohla zmizet sama, treba diky
    # jinemu procesu. Nehlasit selhani, kdyz uz ve skutecnosti neni co hlasit.
    if (-not (Test-Path -LiteralPath `$target)) {
        `$deleted = `$true
        try {
            [System.Windows.Forms.MessageBox]::Show("Slozka ZvukCZ byla uspesne smazana:``n`$target", "Odinstalace ZvukCZ dokoncena", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        } catch {}
    } else {
        Add-Content -Path (Join-Path `$env:TEMP 'zvukcz_uninstall_error.log') -Value "Smazani slozky `$target selhalo po vsech pokusech: `$lastError"
        try {
            [System.Windows.Forms.MessageBox]::Show("Slozku ZvukCZ se nepodarilo automaticky smazat (nejcasteji ji jeste kontroluje antivirus). Smaz ji prosim rucne:``n`$target", "Odinstalace ZvukCZ - nedokoncena", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        } catch {}
    }
}
Remove-Item -LiteralPath '$tempScript' -Force -ErrorAction SilentlyContinue
"@
        Set-Content -Path $tempScript -Value $deleterScript -Encoding UTF8
        # -WorkingDirectory musi mirit mimo mazanou slozku: bez explicitniho
        # nastaveni by tenhle novy proces zdedil pracovni adresar hlavniho
        # odinstalatoru, ktery (kdyz je .exe spusteny primo z instalacni
        # slozky) casto je prave ta mazana slozka - a Windows nedovoli smazat
        # adresar, ktery je necim aktualnim pracovnim adresarem, i kdyz uz je
        # prazdny (overeno realnym testem: obsah slozky se smazal, ale prazdna
        # slozka zustala, dokud tenhle proces nebyl ukoncen).
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -WindowStyle Hidden -WorkingDirectory $env:TEMP

        Step 100 "Hotovo."
        $sync.Success = $true
    }
    catch {
        $sync.ErrorMessage = $_.Exception.Message
        $sync.Success = $false
    }
    finally {
        $sync.Done = $true
    }
}

$script:sync = [Hashtable]::Synchronized(@{
    Log = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    Progress = 0
    CurrentStep = ""
    Done = $false
    Success = $false
    ErrorMessage = ""
})
$script:ps = $null
$script:lastLogCount = 0

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({
    # ArrayList.GetRange() nevraci nezavislou kopii, ale "live" pohled do
    # puvodniho seznamu - kdyz runspace na pozadi mezitim prida dalsi radek
    # (Log), enumerator nad timhle pohledem detekuje zmenu verze a hodi
    # "Collection was modified" (overeno realnym padem). ToArray() naproti
    # tomu vraci skutecnou nezavislou kopii.
    $snapshot = $script:sync.Log.ToArray()
    $count = $snapshot.Length
    if ($count -gt $script:lastLogCount) {
        for ($i = $script:lastLogCount; $i -lt $count; $i++) { $txtLog.AppendText("$($snapshot[$i])`r`n") }
        $script:lastLogCount = $count
    }
    $progressBar.Value = [Math]::Min([Math]::Max([int]$script:sync.Progress, 0), 100)
    $lblStep.Text = $script:sync.CurrentStep

    if ($script:sync.Done -and -not $script:uninstallDone) {
        $script:uninstallDone = $true
        $timer.Stop()
        $script:uninstallRunning = $false
        if ($script:sync.Success) {
            Show-Page 2
        } else {
            $btnCancel.Text = "Zavrit"
            $lblStep.Text = "CHYBA: $($script:sync.ErrorMessage)"
            $lblStep.ForeColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
        }
    }
})

function Start-Uninstall {
    $script:lastLogCount = 0
    $txtLog.Clear()
    $lblStep.ForeColor = [System.Drawing.Color]::Black
    $progressBar.Value = 0
    $script:sync.Log.Clear()
    $script:sync.Progress = 0
    $script:sync.CurrentStep = ""
    $script:sync.Done = $false
    $script:sync.Success = $false
    $script:uninstallDone = $false
    $script:uninstallRunning = $true

    $script:ps = [powershell]::Create()
    [void]$script:ps.AddScript($uninstallSteps).AddArgument($targetDir).AddArgument([bool]$chkPython.Checked).AddArgument($script:sync)
    [void]$script:ps.BeginInvoke()
    $timer.Start()
}

# --- tlacitka ----------------------------------------------------------

$btnNext.Add_Click({
    if ($script:currentPage -eq 0) {
        Show-Page 1
        Start-Uninstall
    }
})

$btnCancel.Add_Click({
    if ($script:currentPage -eq 1 -and $script:uninstallRunning) {
        $r = [System.Windows.Forms.MessageBox]::Show("Odinstalace uz bezi, nedokoncena muze nechat program v nekonzistentnim stavu. Opravdu prerusit?", "ZvukCZ", "YesNo", "Question")
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        try { $timer.Stop(); $script:ps.Stop(); $script:ps.Dispose() } catch {}
    }
    $form.Close()
})

$form.Add_FormClosing({
    param($sender, $e)
    if ($script:currentPage -eq 1 -and $script:uninstallRunning) {
        $r = [System.Windows.Forms.MessageBox]::Show("Odinstalace uz bezi, nedokoncena muze nechat program v nekonzistentnim stavu. Opravdu prerusit?", "ZvukCZ", "YesNo", "Question")
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) {
            $e.Cancel = $true
            return
        }
        try { $timer.Stop(); $script:ps.Stop(); $script:ps.Dispose() } catch {}
    }
})

Show-Page 0
[System.Windows.Forms.Application]::Run($form)

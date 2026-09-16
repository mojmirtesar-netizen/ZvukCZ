$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# $PSScriptRoot je uvnitr zkompilovaneho .exe (ps2exe) nespolehlivy - v
# realnem testu (uninstall_gui.ps1) vysel jako prazdny retezec, ne $null.
# Tady se pouziva jen v lokalnim-dev-behu (kdy $PSScriptRoot funguje
# normalne), ale fallback pres MainModule.FileName je levna pojistka navic.
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
# Ve zkompilovanem ZvukCZ_Install.exe VERSION jeste neni na disku (rozbali
# se az behem instalace) a $PSScriptRoot uvnitr ps2exe je nespolehlivy -
# build_installer.ps1 proto verzi vlozi primo jako $Global:EmbeddedVersion.
if (Get-Variable -Name EmbeddedVersion -Scope Global -ErrorAction SilentlyContinue) {
    $version = $Global:EmbeddedVersion
} else {
    $versionFile = Join-Path $scriptRoot "VERSION"
    $version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "?" }
}

# Soubory, ktere se pri lokalnim spusteni (bez build_installer.ps1) zkopiruji
# do cilove slozky - stejny seznam jako $filesToEmbed v build_installer.ps1,
# jen misto rozbaleni base64 jde o proste kopirovani z repozitare. Pri
# spusteni ze zkompilovaneho ZvukCZ_Install.exe je misto toho pouzita
# $Global:EmbeddedFiles (base64), viz Unpack-Files.
$filesToCopy = @(
    "loopback_translator.py", "run.ps1", "start.bat", "stop.bat",
    "start_helper.ps1", "stop_helper.ps1", "requirements.txt",
    "zvukcz.ico", "README.md", "VERSION", "uninstall_gui.ps1", "uninstall.bat"
)

# --- GUI zaklad ---------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Mumble do CZ - instalace"
$form.ClientSize = New-Object System.Drawing.Size(560, 420)
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
$lblSubtitle.Text = "Instalace v$version (NVIDIA GPU)"
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(210, 230, 240)
$lblSubtitle.Location = New-Object System.Drawing.Point(22, 40)
$lblSubtitle.AutoSize = $true
$header.Controls.Add($lblSubtitle)

$content = New-Object System.Windows.Forms.Panel
$content.Location = New-Object System.Drawing.Point(0, 64)
$content.Size = New-Object System.Drawing.Size(560, 300)
$form.Controls.Add($content)

$separator = New-Object System.Windows.Forms.Panel
$separator.Location = New-Object System.Drawing.Point(0, 364)
$separator.Size = New-Object System.Drawing.Size(560, 1)
$separator.BackColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$form.Controls.Add($separator)

$footer = New-Object System.Windows.Forms.Panel
$footer.Location = New-Object System.Drawing.Point(0, 365)
$footer.Size = New-Object System.Drawing.Size(560, 55)
$form.Controls.Add($footer)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Zrusit"
$btnCancel.Size = New-Object System.Drawing.Size(90, 28)
$btnCancel.Location = New-Object System.Drawing.Point(450, 14)
$footer.Controls.Add($btnCancel)

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = "Dal >"
$btnNext.Size = New-Object System.Drawing.Size(90, 28)
$btnNext.Location = New-Object System.Drawing.Point(350, 14)
$footer.Controls.Add($btnNext)

$btnBack = New-Object System.Windows.Forms.Button
$btnBack.Text = "< Zpet"
$btnBack.Size = New-Object System.Drawing.Size(90, 28)
$btnBack.Location = New-Object System.Drawing.Point(250, 14)
$footer.Controls.Add($btnBack)

$form.AcceptButton = $btnNext
$form.CancelButton = $btnCancel

function New-Page {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point(0, 0)
    $p.Size = New-Object System.Drawing.Size(560, 300)
    $p.Visible = $false
    $content.Controls.Add($p)
    return $p
}

# --- stranka 0: Vitejte ---------------------------------------------------

$pnlWelcome = New-Page
$lblWelcome = New-Object System.Windows.Forms.Label
$lblWelcome.Location = New-Object System.Drawing.Point(24, 20)
$lblWelcome.Size = New-Object System.Drawing.Size(510, 90)
$lblWelcome.Text = "Vitej v instalaci ZvukCZ.`n`nTento pruvodce nainstaluje program, ktery preklada systemovy zvuk do ceskych titulku pomoci NVIDIA GPU. Instalace stahne Python 3.13 (pokud chybi) a potrebne knihovny (vcetne CUDA)."
$pnlWelcome.Controls.Add($lblWelcome)

$lblGpu = New-Object System.Windows.Forms.Label
$lblGpu.Location = New-Object System.Drawing.Point(24, 130)
$lblGpu.Size = New-Object System.Drawing.Size(510, 60)
$lblGpu.Text = "Kontroluji NVIDIA graficku kartu..."
$pnlWelcome.Controls.Add($lblGpu)

$script:gpuOk = $false
try {
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
} catch { $gpu = $null }
if ($gpu) {
    $script:gpuOk = $true
    $lblGpu.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 0)
    $lblGpu.Text = "OK: nalezena NVIDIA karta ($($gpu.Name))"
} else {
    $lblGpu.ForeColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
    $lblGpu.Text = "V tomto pocitaci nebyla nalezena NVIDIA graficka karta.`nTento instalator je jen pro NVIDIA GPU verzi - instalaci nelze pokracovat."
}

# --- stranka 1: Cilova slozka ---------------------------------------------

$pnlLocation = New-Page
$lblLocationInfo = New-Object System.Windows.Forms.Label
$lblLocationInfo.Location = New-Object System.Drawing.Point(24, 20)
$lblLocationInfo.Size = New-Object System.Drawing.Size(510, 40)
$lblLocationInfo.Text = "Kam se ma ZvukCZ nainstalovat? Slozka vznikne, pokud jeste neexistuje."
$pnlLocation.Controls.Add($lblLocationInfo)

$txtLocation = New-Object System.Windows.Forms.TextBox
$txtLocation.Location = New-Object System.Drawing.Point(24, 60)
$txtLocation.Size = New-Object System.Drawing.Size(420, 24)
$txtLocation.Text = Join-Path $env:USERPROFILE "Zvuk to CZ"
$pnlLocation.Controls.Add($txtLocation)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Prochazet..."
$btnBrowse.Location = New-Object System.Drawing.Point(452, 58)
$btnBrowse.Size = New-Object System.Drawing.Size(82, 26)
$pnlLocation.Controls.Add($btnBrowse)
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Vyber slozku pro ZvukCZ"
    if (Test-Path $txtLocation.Text) { $dlg.SelectedPath = $txtLocation.Text }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtLocation.Text = Join-Path $dlg.SelectedPath "Zvuk to CZ"
    }
})

$lblLocationHint = New-Object System.Windows.Forms.Label
$lblLocationHint.Location = New-Object System.Drawing.Point(24, 95)
$lblLocationHint.Size = New-Object System.Drawing.Size(510, 40)
$lblLocationHint.ForeColor = [System.Drawing.Color]::Gray
$lblLocationHint.Text = "Cela slozka bude potrebovat radove jednotky GB volneho mista (Python knihovny + CUDA)."
$pnlLocation.Controls.Add($lblLocationHint)

# --- stranka 2: Volby (DeepL klic) -----------------------------------------

$pnlOptions = New-Page
$lblOptionsInfo = New-Object System.Windows.Forms.Label
$lblOptionsInfo.Location = New-Object System.Drawing.Point(24, 20)
$lblOptionsInfo.Size = New-Object System.Drawing.Size(510, 55)
$lblOptionsInfo.Text = "DeepL API klic (volitelne) - bez nej program jen prepisuje anglicky text, neprekada ho do cestiny.`nZdarma tier: 500 000 znaku/mesic."
$pnlOptions.Controls.Add($lblOptionsInfo)

$lnkDeepL = New-Object System.Windows.Forms.LinkLabel
$lnkDeepL.Location = New-Object System.Drawing.Point(24, 70)
$lnkDeepL.Size = New-Object System.Drawing.Size(400, 20)
$lnkDeepL.Text = "https://www.deepl.com/pro-api"
$lnkDeepL.Add_LinkClicked({ try { Start-Process "https://www.deepl.com/pro-api" } catch {} })
$pnlOptions.Controls.Add($lnkDeepL)

$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Location = New-Object System.Drawing.Point(24, 105)
$lblKey.Size = New-Object System.Drawing.Size(200, 20)
$lblKey.Text = "DeepL API klic:"
$pnlOptions.Controls.Add($lblKey)

$txtDeepLKey = New-Object System.Windows.Forms.TextBox
$txtDeepLKey.Location = New-Object System.Drawing.Point(24, 128)
$txtDeepLKey.Size = New-Object System.Drawing.Size(400, 24)
$pnlOptions.Controls.Add($txtDeepLKey)

$lblKeyHint = New-Object System.Windows.Forms.Label
$lblKeyHint.Location = New-Object System.Drawing.Point(24, 158)
$lblKeyHint.Size = New-Object System.Drawing.Size(510, 40)
$lblKeyHint.ForeColor = [System.Drawing.Color]::Gray
$lblKeyHint.Text = "Muzes nechat prazdne a doplnit pozdeji do souboru deepl_key.txt v instalacni slozce (viz README.md)."
$pnlOptions.Controls.Add($lblKeyHint)

# --- stranka 3: Prubeh instalace -------------------------------------------

$pnlProgress = New-Page
$lblStep = New-Object System.Windows.Forms.Label
$lblStep.Location = New-Object System.Drawing.Point(24, 16)
$lblStep.Size = New-Object System.Drawing.Size(510, 20)
$lblStep.Text = "Pripravuji instalaci..."
$pnlProgress.Controls.Add($lblStep)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(24, 40)
$progressBar.Size = New-Object System.Drawing.Size(510, 20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$pnlProgress.Controls.Add($progressBar)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(24, 70)
$txtLog.Size = New-Object System.Drawing.Size(510, 220)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$txtLog.BackColor = [System.Drawing.Color]::White
$pnlProgress.Controls.Add($txtLog)

# --- stranka 4: Hotovo ------------------------------------------------------

$pnlFinish = New-Page
$lblFinishTitle = New-Object System.Windows.Forms.Label
$lblFinishTitle.Location = New-Object System.Drawing.Point(24, 20)
$lblFinishTitle.Size = New-Object System.Drawing.Size(510, 30)
$lblFinishTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblFinishTitle.Text = "Hotovo!"
$pnlFinish.Controls.Add($lblFinishTitle)

$lblFinishBody = New-Object System.Windows.Forms.Label
$lblFinishBody.Location = New-Object System.Drawing.Point(24, 60)
$lblFinishBody.Size = New-Object System.Drawing.Size(510, 160)
$pnlFinish.Controls.Add($lblFinishBody)

# --- navigace ---------------------------------------------------------------

$panels = @($pnlWelcome, $pnlLocation, $pnlOptions, $pnlProgress, $pnlFinish)
$script:currentPage = 0
$script:installRunning = $false
$script:installDone = $false

function Show-Page($idx) {
    foreach ($p in $panels) { $p.Visible = $false }
    $panels[$idx].Visible = $true
    $script:currentPage = $idx

    switch ($idx) {
        0 {
            $btnBack.Enabled = $false
            $btnNext.Text = "Dal >"
            $btnNext.Visible = $true
            $btnNext.Enabled = $script:gpuOk
            $btnCancel.Text = "Zrusit"
        }
        1 {
            $btnBack.Enabled = $true
            $btnNext.Text = "Dal >"
            $btnNext.Visible = $true
            $btnNext.Enabled = $true
            $btnCancel.Text = "Zrusit"
        }
        2 {
            $btnBack.Enabled = $true
            $btnNext.Text = "Instalovat"
            $btnNext.Visible = $true
            $btnNext.Enabled = $true
            $btnCancel.Text = "Zrusit"
        }
        3 {
            $btnBack.Enabled = $false
            $btnNext.Visible = $false
            $btnCancel.Text = "Zrusit"
        }
        4 {
            $btnBack.Visible = $false
            $btnNext.Visible = $false
            $btnCancel.Text = "Zavrit"
        }
    }
}

# --- instalacni logika (bezi na pozadi v samostatnem runspace) -------------

$installSteps = {
    param($targetDir, $deeplKey, $embedded, $sourceRoot, $filesToCopy, $sync)

    function Log($msg) { [void]$sync.Log.Add([string]$msg) }
    function Step($pct, $text) { $sync.Progress = $pct; $sync.CurrentStep = $text; Log $text }

    # Misto vestaveneho '&' operatoru pouzivame vlastni spousteni procesu
    # (System.Diagnostics.Process, CreateNoWindow=true) - '&' na externi .exe
    # z prostredi bez konzole (ps2exe -NoConsole) muze pro konzolove aplikace
    # (python, pip, winget) na kratko vyblesknout novym konzolovym oknem,
    # presne tomu, co ma tenhle GUI instalator nahradit. Vedlejsi bonus:
    # obchazi i drivejsi problem s 2>&1/2>$null na externich .exe (viz stary
    # install.ps1 - Find-Python), protoze uz vubec nejde pres PowerShellovo
    # nativni-prikaz zpracovani.
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

    function Refresh-Path {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    function Find-Python {
        $cmd = Get-Command python -ErrorAction SilentlyContinue
        if ($cmd) {
            $r = Invoke-Native -FilePath $cmd.Source -CmdArgs @("--version") -Silent
            $ver = (($r.Output -join "`n") + $r.Error)
            if ($ver -match "Python 3\.(1[1-9]|[2-9]\d)") { return $cmd.Source }
        }
        return $null
    }

    try {
        Step 5 "Rozbaluji soubory..."
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        if ($embedded) {
            foreach ($name in $embedded.Keys) {
                $bytes = [System.Convert]::FromBase64String($embedded[$name])
                [System.IO.File]::WriteAllBytes((Join-Path $targetDir $name), $bytes)
            }
        } else {
            foreach ($f in $filesToCopy) {
                $src = Join-Path $sourceRoot $f
                if (Test-Path $src) { Copy-Item -Path $src -Destination (Join-Path $targetDir $f) -Force }
            }
        }
        Log "   OK"

        Step 15 "Kontrola Pythonu..."
        $pythonExe = Find-Python
        if (-not $pythonExe) {
            Log "   Python nenalezen, instaluji pres winget (Python 3.13)..."
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                throw "winget neni k dispozici. Nainstaluj Python rucne z https://python.org a spust instalaci znovu."
            }
            Invoke-Native -FilePath "winget" -CmdArgs @(
                "install", "--id", "Python.Python.3.13", "-e", "--source", "winget",
                "--accept-package-agreements", "--accept-source-agreements"
            ) | Out-Null
            Refresh-Path
            $pythonExe = Find-Python
            if (-not $pythonExe) {
                throw "Python se nepodarilo najit ani po instalaci. Zavri tento instalator, otevri ho znovu a zkus to jeste jednou."
            }
        }
        Log "   OK: $pythonExe"

        Step 30 "Vytvarim virtualni prostredi (.venv)..."
        $venvDir = Join-Path $targetDir ".venv"
        $venvPython = Join-Path $venvDir "Scripts\python.exe"
        if (-not (Test-Path $venvPython)) {
            Invoke-Native -FilePath $pythonExe -CmdArgs @("-m", "venv", $venvDir) | Out-Null
        }
        if (-not (Test-Path $venvPython)) {
            throw "Vytvoreni .venv selhalo (chybi $venvPython). Nejcastejsi priciny: 'python' v PATH je jen zastupny stub z Microsoft Storu, antivirus zablokoval zapis, nebo malo mista na disku."
        }
        Log "   OK"

        Step 45 "Instaluji balicky (muze chvili trvat, stahuji se i CUDA knihovny)..."
        Invoke-Native -FilePath $venvPython -CmdArgs @("-m", "pip", "install", "--upgrade", "pip", "--quiet") | Out-Null
        $r = Invoke-Native -FilePath $venvPython -CmdArgs @("-m", "pip", "install", "-r", (Join-Path $targetDir "requirements.txt"))
        if ($r.ExitCode -ne 0) {
            throw "Instalace balicku selhala (pip skoncil s chybou). Zkontroluj pripojeni k internetu a spust instalaci znovu."
        }
        Log "   OK"

        Step 80 "Overuji GPU..."
        $r = Invoke-Native -FilePath $venvPython -CmdArgs @("-c", "import ctranslate2; print(ctranslate2.get_cuda_device_count())") -Silent
        $cudaCount = ($r.Output -join "").Trim()
        if ($cudaCount -match "^\d+$" -and [int]$cudaCount -ge 1) {
            Log "   OK, GPU pripraveno ($cudaCount zarizeni)"
        } else {
            Log "   POZOR: GPU se nepodarilo overit, zkontroluj ovladace NVIDIA karty."
        }

        Step 90 "Ukladam nastaveni..."
        if ($deeplKey) {
            Set-Content -Path (Join-Path $targetDir "deepl_key.txt") -Value $deeplKey -NoNewline
            Log "   DeepL klic ulozen."
        } else {
            Log "   DeepL klic preskocen (lze doplnit pozdeji v deepl_key.txt)."
        }

        Step 95 "Vytvarim zastupce na plose..."
        try {
            $shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "ZvukCZ.lnk"
            $wsh = New-Object -ComObject WScript.Shell
            $sc = $wsh.CreateShortcut($shortcutPath)
            $sc.TargetPath = "powershell.exe"
            $sc.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$targetDir\start_helper.ps1`""
            $sc.WorkingDirectory = $targetDir
            $sc.IconLocation = "$targetDir\zvukcz.ico"
            $sc.Description = "ZvukCZ - preklad systemoveho zvuku do titulku"
            $sc.Save()
            Log "   OK: $shortcutPath"
        } catch {
            Log "   Zastupce na plose se nepodarilo vytvorit: $_"
        }

        Step 100 "Hotovo!"
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

    if ($script:sync.Done -and -not $script:installDone) {
        $script:installDone = $true
        $timer.Stop()
        $script:installRunning = $false
        if ($script:sync.Success) {
            $lblFinishBody.Text = "ZvukCZ je nainstalovan v:`n$($txtLocation.Text)`n`nSpusteni: zastupce ZvukCZ na plose (nebo start.bat ve slozce).`nZastaveni: stop.bat.`nOdinstalace: uninstall.bat ve slozce."
            Show-Page 4
        } else {
            $btnBack.Visible = $true
            $btnBack.Enabled = $true
            $btnBack.Text = "Zkusit znovu"
            $btnCancel.Text = "Zavrit"
            $lblStep.Text = "CHYBA: $($script:sync.ErrorMessage)"
            $lblStep.ForeColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
        }
    }
})

function Start-Install {
    $script:lastLogCount = 0
    $txtLog.Clear()
    $lblStep.ForeColor = [System.Drawing.Color]::Black
    $progressBar.Value = 0
    $script:sync.Log.Clear()
    $script:sync.Progress = 0
    $script:sync.CurrentStep = ""
    $script:sync.Done = $false
    $script:sync.Success = $false
    $script:installDone = $false
    $script:installRunning = $true

    $embedded = if (Get-Variable -Name EmbeddedFiles -Scope Global -ErrorAction SilentlyContinue) { $Global:EmbeddedFiles } else { $null }

    $script:ps = [powershell]::Create()
    [void]$script:ps.AddScript($installSteps).AddArgument($txtLocation.Text).AddArgument($txtDeepLKey.Text).AddArgument($embedded).AddArgument($scriptRoot).AddArgument($filesToCopy).AddArgument($script:sync)
    [void]$script:ps.BeginInvoke()
    $timer.Start()
}

# --- tlacitka ----------------------------------------------------------

$btnNext.Add_Click({
    switch ($script:currentPage) {
        0 { Show-Page 1 }
        1 {
            $target = $txtLocation.Text.Trim()
            if (-not $target) {
                [System.Windows.Forms.MessageBox]::Show("Zadej cilovou slozku.", "ZvukCZ", "OK", "Warning") | Out-Null
                return
            }
            try {
                New-Item -ItemType Directory -Force -Path $target -ErrorAction Stop | Out-Null
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Do teto slozky nejde zapisovat: $_", "ZvukCZ", "OK", "Error") | Out-Null
                return
            }
            Show-Page 2
        }
        2 {
            Show-Page 3
            Start-Install
        }
    }
})

$btnBack.Add_Click({
    if ($script:currentPage -eq 3 -and -not $script:installRunning) {
        # navrat po chybe - reset na stranku s umistenim
        $btnBack.Text = "< Zpet"
        Show-Page 1
        return
    }
    if ($script:currentPage -gt 0) { Show-Page ($script:currentPage - 1) }
})

$btnCancel.Add_Click({
    if ($script:currentPage -eq 3 -and $script:installRunning) {
        $r = [System.Windows.Forms.MessageBox]::Show("Opravdu prerusit instalaci?", "ZvukCZ", "YesNo", "Question")
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        try { $timer.Stop(); $script:ps.Stop(); $script:ps.Dispose() } catch {}
    }
    $form.Close()
})

$form.Add_FormClosing({
    param($sender, $e)
    if ($script:currentPage -eq 3 -and $script:installRunning) {
        $r = [System.Windows.Forms.MessageBox]::Show("Opravdu prerusit instalaci?", "ZvukCZ", "YesNo", "Question")
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) {
            $e.Cancel = $true
            return
        }
        try { $timer.Stop(); $script:ps.Stop(); $script:ps.Dispose() } catch {}
    }
})

Show-Page 0
[System.Windows.Forms.Application]::Run($form)

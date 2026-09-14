$env:HF_HUB_DISABLE_XET = "1"

$keyFile = Join-Path $PSScriptRoot "deepl_key.txt"
if (Test-Path $keyFile) {
    $env:DEEPL_KEY = (Get-Content $keyFile -Raw).Trim()
}

& "$PSScriptRoot\.venv\Scripts\python.exe" "$PSScriptRoot\loopback_translator.py"

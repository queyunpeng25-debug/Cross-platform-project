$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (-not (Test-Path -LiteralPath '.venv\Scripts\python.exe')) {
    Write-Host 'Run: python -m venv .venv'
    Write-Host 'Then: .\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt'
    exit 1
}
& .\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 0.0.0.0 --port 8000

# ORCA Prototype Launcher (FastAPI Backend + Web Dashboard)
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Starting ORCA Marine AI Prototype (ISRO 26176)..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Start Backend
Write-Host "`n[1/2] Starting FastAPI Backend on http://localhost:8000 ..." -ForegroundColor Yellow
$backendJob = Start-Process -FilePath "py" -ArgumentList "-3.14", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload" -WorkingDirectory "$PSScriptRoot\backend" -PassThru

Start-Sleep -Seconds 3

# 2. Open Web Dashboard
Write-Host "`n[2/2] Opening Web Dashboard (frontend/index.html) in browser ..." -ForegroundColor Yellow
$frontendPath = "$PSScriptRoot\frontend\index.html"
if (Test-Path $frontendPath) {
    Start-Process "file:///$($frontendPath -replace '\\', '/')"
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "ORCA Prototype is running!" -ForegroundColor Green
Write-Host "   - API Docs & Swagger: http://localhost:8000/docs" -ForegroundColor White
Write-Host "   - Health Check:      http://localhost:8000/health" -ForegroundColor White
Write-Host "   - Web Dashboard:     frontend/index.html" -ForegroundColor White
Write-Host "   - Mobile App:        cd mobile; flutter run" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Press Ctrl+C or close this terminal window to exit.`n"

# Wait for backend process
Wait-Process -Id $backendJob.Id

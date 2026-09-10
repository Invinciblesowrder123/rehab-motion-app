# Run the Flutter app on a physical Android phone and connect it to the local API.
# Uses `adb reverse` so the phone reaches the PC API through localhost:3000 over USB.
# No Wi-Fi and no firewall rule needed.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\phone_run.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\phone_run.ps1 -DeviceId <adb-id> -ApiPort 3000

param(
    [string]$DeviceId = "",
    [int]$ApiPort = 3000
)

$ErrorActionPreference = "Stop"

$adb = "C:\Users\zcjte\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$flutter = "D:\dev\flutter\bin\flutter.bat"
$project = "D:\AI\R\rehab-motion-mvp\apps\mobile"

if (-not (Test-Path $adb)) { throw "adb not found: $adb" }
if (-not (Test-Path $flutter)) { throw "flutter not found: $flutter" }

Write-Host "== Step 1: adb devices ==" -ForegroundColor Cyan
& $adb devices -l

$lines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\S" }
if (-not $lines) {
    Write-Host ""
    Write-Host "NO ANDROID DEVICE DETECTED." -ForegroundColor Red
    Write-Host "Checklist:" -ForegroundColor Yellow
    Write-Host "  1. Phone: Settings > About phone > tap Build number 7 times to unlock Developer options"
    Write-Host "  2. Settings > Developer options > enable 'USB debugging'"
    Write-Host "  3. If 'USB tethering / USB network sharing' is ON, turn it OFF (it blocks adb on many phones)"
    Write-Host "  4. Plug USB, set USB mode to 'File transfer / MTP'"
    Write-Host "  5. On the phone accept the 'Allow USB debugging?' prompt (check Always allow)"
    Write-Host "  6. Run this script again"
    exit 1
}

$device = $lines[0].Split("`t")[0].Trim()
$status = $lines[0]
if ($status -match "unauthorized") {
    Write-Host ""
    Write-Host "DEVICE UNAUTHORIZED." -ForegroundColor Red
    Write-Host "Look at the phone screen and accept 'Allow USB debugging', then run this script again."
    exit 1
}
if ($status -match "offline") {
    Write-Host "DEVICE OFFLINE. Re-plug the USB cable and try again." -ForegroundColor Red
    exit 1
}
if ($DeviceId -ne "") { $device = $DeviceId }

Write-Host ""
Write-Host "Using device: $device" -ForegroundColor Green

Write-Host ""
Write-Host "== Step 2: check local API on port $ApiPort ==" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/health" -TimeoutSec 5
    Write-Host "API OK: $($health | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    Write-Host "API NOT REACHABLE on http://127.0.0.1:$ApiPort/health" -ForegroundColor Yellow
    Write-Host "Start it in another window:" -ForegroundColor Yellow
    Write-Host "  cd D:\AI\R\rehab-motion-mvp\apps\api"
    Write-Host "  npm run build"
    Write-Host "  `$env:PORT='$ApiPort'; `$env:CORS_ORIGINS='*'; node dist/main.js"
    Write-Host "Continuing anyway; the app will show a network error until the API is up."
}

Write-Host ""
Write-Host "== Step 3: adb reverse tcp:$ApiPort -> tcp:$ApiPort ==" -ForegroundColor Cyan
& $adb -s $device reverse "tcp:$ApiPort" "tcp:$ApiPort"
if ($LASTEXITCODE -ne 0) { throw "adb reverse failed" }
Write-Host "Reverse OK. Phone localhost:$ApiPort now forwards to PC localhost:$ApiPort" -ForegroundColor Green

Write-Host ""
Write-Host "== Step 4: flutter run ==" -ForegroundColor Cyan
Set-Location $project
& $flutter pub get
& $flutter run -d $device "--dart-define=API_BASE_URL=http://127.0.0.1:$ApiPort"

Write-Host ""
Write-Host "Remember: 'adb reverse' is lost when you unplug USB or reboot the phone." -ForegroundColor Yellow
Write-Host "Re-run this script after reconnecting." -ForegroundColor Yellow

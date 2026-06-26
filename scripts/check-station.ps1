# Cert Label Station — health check. Confirms everything is set up correctly.
#
# Run this as the NORMAL (non-admin) user who will actually print — that's the whole
# point: it proves the connection works for THEM. No admin needed.
#
#   irm https://github.com/MasterVision1/mrg-cert-labels/raw/main/scripts/check-station.ps1 | iex

$ErrorActionPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$pass = 0; $fail = 0
function Result($ok, $label, $fixHint) {
  if ($ok) { Write-Host ("  [ OK ]  " + $label) -ForegroundColor Green; $script:pass++ }
  else     { Write-Host ("  [FAIL]  " + $label) -ForegroundColor Red;   $script:fail++; if ($fixHint) { Write-Host ("          -> " + $fixHint) -ForegroundColor Yellow } }
}

Write-Host "`n=== Cert Label Station — checking this PC (as $env:USERNAME) ===`n" -ForegroundColor Cyan

# 1. DYMO Connect installed
$hostExe = "C:\Program Files (x86)\DYMO\DYMO Connect\DYMO.WebApi.Win.Host.exe"
Result (Test-Path $hostExe) "DYMO Connect is installed" "Install it: run the setup line in an Admin PowerShell."

# 2. Always-on SYSTEM service (or machine Run key fallback) — the fix for non-admin users
$taskOk = [bool](Get-ScheduledTask -TaskName 'DYMO Web Service (all users)' -ErrorAction SilentlyContinue)
$runVal = (Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'DYMOWebApi').DYMOWebApi
Result ($taskOk -or [bool]$runVal) "Web service set to run for every user (always-on/SYSTEM)" "Re-run the setup (provision-station.ps1) in an Admin PowerShell."

# 3. Cert trusted machine-wide (so every user's browser trusts it)
$certOk = [bool](Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*DYMO*')
Result $certOk "DYMO certificate trusted machine-wide" "Re-run the setup in an Admin PowerShell to trust it."

# 4. Web service actually running right now (in THIS user's session)
$proc = Get-Process -Name 'DYMO.WebApi.Win.Host'
Result ([bool]$proc) "DYMO web service is running for this user" "Sign out and back in (HKLM auto-start launches it at login), or open the DYMO Connect app once."

# 5. Service answers on the network (uses the same trust path the browser does) -> THE key test
$answerPort = $null
foreach ($p in 41951..41960) {
  try {
    $r = Invoke-WebRequest "https://127.0.0.1:$p/DYMO/DLS/Printing/StatusConnected" -TimeoutSec 4 -UseBasicParsing
    if ($r.Content -match 'true|false') { $answerPort = $p; break }
  } catch {}
}
Result ([bool]$answerPort) ("App can connect to DYMO" + $(if($answerPort){" (port $answerPort)"})) "If 1-4 pass but this fails, sign out/in once; the cert + service then line up."

# 6. A printer is connected
$printerName = $null
if ($answerPort) {
  try {
    $xml = (Invoke-WebRequest "https://127.0.0.1:$answerPort/DYMO/DLS/Printing/GetPrinters" -TimeoutSec 4 -UseBasicParsing).Content
    if ($xml -match '<IsConnected>True</IsConnected>') {
      if ($xml -match '<Name>([^<]+)</Name>') { $printerName = $matches[1] }
    }
  } catch {}
}
Result ([bool]$printerName) ("DYMO printer connected" + $(if($printerName){" ($printerName)"})) "Plug the DYMO LabelWriter into this PC with its USB cable (no admin needed)."

Write-Host ""
if ($fail -eq 0) {
  Write-Host "ALL GOOD ($pass/$pass). This station is ready — open the Cert Label Station and print." -ForegroundColor Green
} else {
  Write-Host "$pass passed, $fail need attention (see the -> hints above)." -ForegroundColor Yellow
  Write-Host "Most issues are fixed by signing out/in once, or re-running the Admin setup line." -ForegroundColor Yellow
}
Write-Host ""
if ([Environment]::UserInteractive -and $Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to close" }

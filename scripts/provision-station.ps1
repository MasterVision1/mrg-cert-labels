# =====================================================================================
#  Cert Label Station — ONE-TIME station provisioning (run once, elevated, per PC)
# =====================================================================================
#  Run this ONCE per printing PC as an administrator. After it finishes, EVERY user of
#  that PC — admin OR standard — can open the Cert Label Station and print with NO admin
#  prompts and NO per-user setup. IT (Keith) never has to come back to the machine.
#
#  It fixes the real "works as admin, standard user can't connect" cause:
#    * DYMO's web service (DYMO.WebApi.Win.Host.exe, the thing on 127.0.0.1:41951) is
#      NOT a Windows service — DYMO auto-starts it from the *installing user's* HKCU Run
#      key. So it only launches for THAT user. Standard users get a different HKCU, the
#      service never starts in their session, and the app shows "can't connect".
#    * This script moves that auto-start to the MACHINE Run key (HKLM), so the service
#      starts for every user at login. It also trusts the cert machine-wide and starts
#      the service right now.
#
#  HOW TO RUN:
#    Right-click Start -> "Terminal (Admin)" / "Windows PowerShell (Admin)", then:
#      irm https://raw.githubusercontent.com/MasterVision1/mrg-cert-labels/main/scripts/provision-station.ps1 | iex
# =====================================================================================

$ErrorActionPreference = 'Stop'

function Assert-Admin {
  $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "This must run in an ELEVATED PowerShell (Run as administrator). Re-open as Admin and retry." -ForegroundColor Red
    exit 1
  }
}
Assert-Admin
Write-Host "`n=== Cert Label Station — provisioning this PC ===`n" -ForegroundColor Cyan

# ---- 1. Ensure DYMO Connect is installed -------------------------------------------
$dymoDir  = "C:\Program Files (x86)\DYMO\DYMO Connect"
$hostExe  = Join-Path $dymoDir "DYMO.WebApi.Win.Host.exe"
$helperEx = Join-Path $dymoDir "DYMO.OfficeHelper.exe"

if (-not (Test-Path $hostExe)) {
  Write-Host "[1/5] DYMO Connect not found — installing..." -ForegroundColor Yellow
  $installed = $false
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
      winget install --id DYMO.DYMOConnect --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
      if (Test-Path $hostExe) { $installed = $true }
    } catch {}
  }
  if (-not $installed) {
    Write-Host "      winget unavailable/failed — downloading the installer..." -ForegroundColor Yellow
    $exe = Join-Path $env:TEMP "DCDSetup.exe"
    Invoke-WebRequest "https://download.dymo.com/dymo/Software/Win/DCDSetup1.5.1.20.exe" -OutFile $exe
    # DCD installer is Advanced Installer based; /exenoui /qn runs it silently.
    Start-Process $exe -ArgumentList '/exenoui','/qn' -Wait
    if (-not (Test-Path $hostExe)) {
      Write-Host "      Silent install didn't complete. Launching the installer UI — click through it, then re-run this script." -ForegroundColor Yellow
      Start-Process $exe -Wait
    }
  }
  if (-not (Test-Path $hostExe)) { Write-Host "DYMO Connect still not installed. Install it manually, then re-run." -ForegroundColor Red; exit 1 }
  Write-Host "[1/5] DYMO Connect installed." -ForegroundColor Green
} else {
  Write-Host "[1/5] DYMO Connect already installed." -ForegroundColor Green
}

# ---- 2. Make the web service auto-start for ALL users (THE key fix) -----------------
# Move the per-user auto-start to the machine Run key so every login starts the service.
$runHKLM = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
Set-ItemProperty -Path $runHKLM -Name 'DYMOWebApi' -Value ('"{0}" /auto' -f $hostExe)
if (Test-Path $helperEx) { Set-ItemProperty -Path $runHKLM -Name 'DymoOfficeHelper' -Value ('"{0}" /w' -f $helperEx) }
# Remove the installing-admin's per-user copy so there aren't duplicates (best effort).
try { Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'DYMOWebApi' -ErrorAction SilentlyContinue } catch {}
Write-Host "[2/5] Web service set to auto-start for every user (HKLM Run)." -ForegroundColor Green

# ---- 3. Start the web service now (this session) -----------------------------------
if (-not (Get-Process -Name 'DYMO.WebApi.Win.Host' -ErrorAction SilentlyContinue)) {
  Start-Process $hostExe -ArgumentList '/auto'
  Start-Sleep -Seconds 3
}
Write-Host "[3/5] Web service running." -ForegroundColor Green

# ---- 4. Trust the DYMO cert machine-wide (covers ALL users, no per-user prompt) ----
$port = $null
foreach ($p in 41951..41960) {
  try {
    $t = [Net.Sockets.TcpClient]::new(); $iar = $t.BeginConnect('127.0.0.1',$p,$null,$null)
    if ($iar.AsyncWaitHandle.WaitOne(400) -and $t.Connected) { $port = $p; $tcp = $t; break }; $t.Close()
  } catch {}
}
if ($port) {
  try {
    $ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false, ([Net.Security.RemoteCertificateValidationCallback]{ $true }))
    $ssl.AuthenticateAsClient('127.0.0.1')
    $leaf = [Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
    $ssl.Dispose(); $tcp.Dispose()
    $chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
    $chain.ChainPolicy.RevocationMode = 'NoCheck'; $chain.ChainPolicy.VerificationFlags = 'AllowUnknownCertificateAuthority'
    [void]$chain.Build($leaf)
    $root = $chain.ChainElements[$chain.ChainElements.Count-1].Certificate
    $store = [Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine')
    $store.Open('ReadWrite'); $store.Add($root)
    if ($root.Thumbprint -ne $leaf.Thumbprint) { $store.Add($leaf) }; $store.Close()
    Write-Host "[4/5] Cert trusted machine-wide on 127.0.0.1:$port." -ForegroundColor Green
  } catch { Write-Host "[4/5] Couldn't auto-trust the cert ($($_.Exception.Message)). DYMO's installer usually trusts it; if the app still won't connect, tell IT." -ForegroundColor Yellow }
} else {
  Write-Host "[4/5] Web service didn't answer on 41951-41960 yet — it may still be starting. Cert trust skipped; re-run if needed." -ForegroundColor Yellow
}

# ---- 5. Verify -------------------------------------------------------------------
$ok = $false
foreach ($p in 41951..41960) {
  try {
    $r = Invoke-WebRequest "https://127.0.0.1:$p/DYMO/DLS/Printing/StatusConnected" -TimeoutSec 4 -UseBasicParsing
    if ($r.Content -match 'true|false') { Write-Host "[5/5] VERIFIED: DYMO web service answering on 127.0.0.1:$p." -ForegroundColor Green; $ok = $true; break }
  } catch {}
}
Write-Host ""
if ($ok) {
  Write-Host "DONE. This station is provisioned for ALL users. Plug in the DYMO printer (no admin needed)," -ForegroundColor Green
  Write-Host "then open the Cert Label Station — it connects automatically. No more admin prompts." -ForegroundColor Green
} else {
  Write-Host "Setup applied, but verification didn't get a response. Open the DYMO Connect app once, then re-run this script." -ForegroundColor Yellow
}

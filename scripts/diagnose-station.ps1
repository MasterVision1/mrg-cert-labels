# Cert Label Station — DEEP diagnosis. Run on the machine that won't connect, as the
# normal user. Read-only, no admin needed. Shows WHY it can't reach DYMO, not just that
# it can't. Paste the whole output back.
#
#   irm https://github.com/MasterVision1/mrg-cert-labels/raw/main/scripts/diagnose-station.ps1 | iex

$ErrorActionPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
function H($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }

Write-Host "DYMO connection diagnosis — $env:COMPUTERNAME / user $env:USERNAME" -ForegroundColor White

H "1. DYMO Connect installed?"
$hostExe = "C:\Program Files (x86)\DYMO\DYMO Connect\DYMO.WebApi.Win.Host.exe"
if (Test-Path $hostExe) {
  $v = (Get-Item $hostExe).VersionInfo.ProductVersion
  Write-Host "  YES — version $v"
} else { Write-Host "  NO — DYMO.WebApi.Win.Host.exe not found. (Install DYMO Connect.)" -ForegroundColor Red }

H "2. Is the DYMO web host process running? (and as whom)"
$procs = Get-CimInstance Win32_Process -Filter "Name='DYMO.WebApi.Win.Host.exe'"
if ($procs) {
  foreach ($p in $procs) { $o=Invoke-CimMethod -InputObject $p -MethodName GetOwner; Write-Host ("  RUNNING  PID {0}  as {1}\{2}" -f $p.ProcessId,$o.Domain,$o.User) }
} else { Write-Host "  NOT RUNNING — nothing is hosting the DYMO service in any session." -ForegroundColor Red }

H "3. What is actually LISTENING on 41951-41960?"
$listening = @()
foreach ($port in 41951..41960) {
  $c = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue
  if ($c) { $listening += $port; Write-Host ("  port {0}: LISTENING (pid {1})" -f $port, ($c.OwningProcess | Select-Object -First 1)) }
}
if (-not $listening) { Write-Host "  NOTHING is listening on 41951-41960 — the service isn't up on this PC." -ForegroundColor Red }

H "4. Raw HTTPS test to each port (the REAL error if it fails)"
foreach ($port in 41951..41960) {
  try {
    $r = Invoke-WebRequest "https://127.0.0.1:$port/DYMO/DLS/Printing/StatusConnected" -TimeoutSec 4 -UseBasicParsing
    Write-Host ("  port {0}: OK -> '{1}'" -f $port,$r.Content) -ForegroundColor Green
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match 'actively refused|unable to connect|No connection') { }   # silent: nothing there
    else { Write-Host ("  port {0}: ERROR -> {1}" -f $port,$msg) -ForegroundColor Yellow }
  }
}

H "5. Is the DYMO certificate trusted on this PC?"
$lm = Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*DYMO*'
$cu = Get-ChildItem Cert:\CurrentUser\Root  | Where-Object Subject -like '*DYMO*'
Write-Host ("  Machine-wide (LocalMachine\Root): {0}" -f $(if($lm){"YES"}else{"NO"})) -ForegroundColor $(if($lm){'Green'}else{'Red'})
Write-Host ("  This user   (CurrentUser\Root):  {0}" -f $(if($cu){"YES"}else{"NO"}))

H "6. Security software that can block localhost"
$av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
if ($av) { $av | ForEach-Object { Write-Host ("  Antivirus: {0}" -f $_.displayName) } } else { Write-Host "  (Could not read AV list — may be a server, or none.)" }
Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("  Firewall [{0}]: {1}" -f $_.Name, $(if($_.Enabled){'ON'}else{'off'})) }

H "7. localhost resolution"
Write-Host ("  127.0.0.1 reachable (tcp 41951 syn): {0}" -f $(try{ (Test-NetConnection 127.0.0.1 -Port 41951 -WarningAction SilentlyContinue).TcpTestSucceeded }catch{'?'}))

Write-Host "`n--- copy everything above and send it back ---`n" -ForegroundColor Cyan
if ([Environment]::UserInteractive -and $Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to close" }

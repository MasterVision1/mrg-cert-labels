# Trust the DYMO local web-service certificate for the CURRENT USER, so the browser
# connects to DYMO Connect automatically (and stays connected across restarts).
#
# NO ADMINISTRATOR REQUIRED. This installs the cert into the per-user trust store
# (CurrentUser\Root), which Edge/Chrome honor exactly like the machine store — so the
# shop operator can run this themselves. The IT admin does NOT need to log in.
#
# WHY: DYMO Connect runs a local HTTPS service (127.0.0.1, port 41951-41960) with a
# self-signed cert issued by "DYMO Root CA (for localhost)". If that root CA isn't
# trusted for the logged-in user, the browser silently refuses the connection and the
# Cert Label Station shows "Connect DYMO" even though DYMO Connect is installed.
#
# HOW TO RUN (one time per Windows user on a printing station):
#   1. Make sure DYMO Connect is installed and running (green tray icon).
#   2. Open a NORMAL PowerShell (Start -> type "PowerShell" -> Enter). NOT "as Admin".
#   3. Paste:  irm https://raw.githubusercontent.com/MasterVision1/mrg-cert-labels/main/scripts/trust-dymo-cert.ps1 | iex
#   4. If Windows pops a "Do you want to install this certificate?" box, click Yes.
#   5. Close and reopen the browser. The station connects automatically.

$ErrorActionPreference = 'Stop'

# DYMO Connect picks the first free port in this range at startup, so scan it.
$port = $null
foreach ($p in 41951..41960) {
  try {
    $t = [Net.Sockets.TcpClient]::new()
    $iar = $t.BeginConnect('127.0.0.1', $p, $null, $null)
    if ($iar.AsyncWaitHandle.WaitOne(300) -and $t.Connected) { $port = $p; $tcp = $t; break }
    $t.Close()
  } catch {}
}
if (-not $port) {
  Write-Host "DYMO Connect isn't running (nothing answered on 127.0.0.1:41951-41960)." -ForegroundColor Yellow
  Write-Host "Open the DYMO Connect app (green tray icon), then re-run this." -ForegroundColor Yellow
  return
}
Write-Host "Found DYMO Connect on 127.0.0.1:$port" -ForegroundColor Cyan

# Pull the cert the service is presenting.
$ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false, ([Net.Security.RemoteCertificateValidationCallback] { $true }))
$ssl.AuthenticateAsClient('127.0.0.1')
$leaf = [Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
$ssl.Dispose(); $tcp.Dispose()

# Resolve its root CA.
$chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
$chain.ChainPolicy.RevocationMode = 'NoCheck'
$chain.ChainPolicy.VerificationFlags = 'AllowUnknownCertificateAuthority'
[void]$chain.Build($leaf)
$root = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate

# Install into the PER-USER trust store — no elevation needed.
try {
  $store = [Security.Cryptography.X509Certificates.X509Store]::new('Root', 'CurrentUser')
  $store.Open('ReadWrite')
  $store.Add($root)        # also covers leaf-as-root when there's no separate CA
  if ($root.Thumbprint -ne $leaf.Thumbprint) { $store.Add($leaf) }
  $store.Close()
  Write-Host "Trusted for this user: $($root.Subject)" -ForegroundColor Green
  Write-Host "Done. Close and reopen Chrome/Edge, then the Cert Label Station connects automatically." -ForegroundColor Green
} catch {
  Write-Host "Couldn't write to your user trust store: $($_.Exception.Message)" -ForegroundColor Yellow
  Write-Host "If a 'Do you want to install this certificate?' box appeared, click Yes and re-run." -ForegroundColor Yellow
}

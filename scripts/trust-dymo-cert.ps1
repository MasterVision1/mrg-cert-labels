# Trust the DYMO local web-service certificate on this PC, so the browser connects
# to DYMO Connect automatically (and stays connected across restarts).
#
# WHY: DYMO Connect runs a local HTTPS service (127.0.0.1:41951) with a self-signed
# cert issued by "DYMO Root CA (for localhost)". If that root CA isn't trusted, the
# browser silently refuses the connection and the Cert Label Station shows
# "Connect DYMO" even though DYMO Connect is installed and running.
#
# HOW TO RUN (one time per printing station):
#   1. Make sure DYMO Connect is installed and running (tray icon).
#   2. Right-click Start -> "Terminal (Admin)" / "Windows PowerShell (Admin)".
#   3. Paste:  irm https://raw.githubusercontent.com/MasterVision1/mrg-cert-labels/main/scripts/trust-dymo-cert.ps1 | iex
#      (or run this file directly elevated)
#   4. Close and reopen the browser. The station connects automatically.

$ErrorActionPreference = 'Stop'
try {
  $tcp = [Net.Sockets.TcpClient]::new('127.0.0.1', 41951)
} catch {
  Write-Host "DYMO Connect is not running on 127.0.0.1:41951. Open DYMO Connect first, then re-run." -ForegroundColor Yellow
  return
}
$ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false, ([Net.Security.RemoteCertificateValidationCallback] { $true }))
$ssl.AuthenticateAsClient('127.0.0.1')
$leaf = [Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
$ssl.Dispose(); $tcp.Dispose()

$chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
$chain.ChainPolicy.RevocationMode = 'NoCheck'
$chain.ChainPolicy.VerificationFlags = 'AllowUnknownCertificateAuthority'
[void]$chain.Build($leaf)
$root = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate

try {
  $store = [Security.Cryptography.X509Certificates.X509Store]::new('Root', 'LocalMachine')
  $store.Open('ReadWrite')
  $store.Add($root)        # also adds the leaf-as-root if no separate CA
  if ($root.Thumbprint -ne $leaf.Thumbprint) { $store.Add($leaf) }
  $store.Close()
  Write-Host "Trusted: $($root.Subject)" -ForegroundColor Green
  Write-Host "Done. Close and reopen Chrome/Edge, then the Cert Label Station will connect automatically." -ForegroundColor Green
} catch {
  Write-Host "Could not write to the machine trust store. Re-run this in an ELEVATED (Admin) PowerShell." -ForegroundColor Yellow
}

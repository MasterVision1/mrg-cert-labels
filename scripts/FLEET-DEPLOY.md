# Cert Label Station — fleet deployment (for Keith / IT)

Environment: on-prem Active Directory domain **`mrg.local`** (no Intune). The tool is
**Group Policy**. Goal: every shop station connects for **every** user (admin *or*
standard) with no per-machine fiddling.

## What actually needs to happen on each station
1. **DYMO Connect installed** — software, so it must land on each PC once (needs admin). Unavoidable.
2. **Web service auto-starts for ALL users** — the real bug. DYMO normally auto-starts
   its web service (`DYMO.WebApi.Win.Host.exe`, port 41951) from the *installing user's*
   `HKCU\…\Run` key, so it never starts for other users. Move it to the **machine** Run key.
3. **DYMO Root CA trusted machine-wide** — so every user's browser trusts the localhost cert.

GPO handles #2 and #3 for the whole fleet at once. #1 is per-PC (see options below).

---

## Recommended: GPO for the fix (#2 + #3), install DYMO during PC build (#1)

Most reliable — the fix is enforced fleet-wide and reapplies automatically; DYMO install
isn't tangled into SYSTEM context.

### A. Push the all-users auto-start (registry)
GPMC → new GPO (e.g. "Cert Label Station") → **Computer Configuration → Preferences →
Windows Settings → Registry → New → Registry Item**:
- Action: **Update**
- Hive: `HKEY_LOCAL_MACHINE`
- Key Path: `Software\Microsoft\Windows\CurrentVersion\Run`
- Value name: `DYMOWebApi`
- Value type: `REG_SZ`
- Value data: `"C:\Program Files (x86)\DYMO\DYMO Connect\DYMO.WebApi.Win.Host.exe" /auto`

### B. Push the trusted root cert
On the one working station, export the DYMO root CA:
```powershell
Get-ChildItem Cert:\LocalMachine\Root |
  Where-Object Subject -like '*DYMO Root CA*' |
  ForEach-Object { Export-Certificate -Cert $_ -FilePath "$env:USERPROFILE\Desktop\DymoRootCA.cer" }
```
Then in the same GPO → **Computer Configuration → Policies → Windows Settings → Security
Settings → Public Key Policies → Trusted Root Certification Authorities → Import** →
select `DymoRootCA.cer`.

### C. Link + apply
Link the GPO to the OU that holds the shop-station computers. On a station:
`gpupdate /force`, then **reboot** (the auto-start fires at login). Done — every user connects.

### D. Install DYMO Connect on each station (one-time, per PC)
During the normal PC build, run this once (it self-elevates — click Yes):
```
irm https://github.com/MasterVision1/mrg-cert-labels/raw/main/scripts/provision-station.ps1 | iex
```
It installs DYMO **and** applies the same fix locally (belt-and-suspenders with the GPO).

---

## Alternative: one GPO does everything (startup script)

If you'd rather have GPO also install DYMO: drop `provision-station.ps1` on a share
readable by the computers (e.g. SYSVOL), then GPMC → **Computer Configuration → Policies
→ Windows Settings → Scripts (Startup/Shutdown) → Startup → PowerShell Scripts → Add** the
script. It runs as SYSTEM at boot, is idempotent, and self-installs DYMO + applies the fix.

Caveat: `winget` isn't available under SYSTEM, so the script falls back to the silent
`.exe` installer. If a model of station won't silent-install cleanly, install DYMO there
once via step D and let the GPO handle the rest.

---

## Verify a station
As a **normal (non-admin) user**, after reboot:
- Open the Cert Label Station → it should show **DYMO ready** with no prompts.
- Or check the service is up: paste `https://127.0.0.1:41951/DYMO/DLS/Printing/StatusConnected`
  into Edge — should say `true`.

# Cert Label Station — set up ALL computers at once (do this ONCE)

You do this **one time** on the domain. After that, **every** shop computer — and
**every** user on them, admin or not — gets DYMO set up automatically and connects with
zero clicks. New computers added later are covered too.

You need: an account that can edit Group Policy (Domain Admin), on any domain-joined PC.

---

## Step 1 — Save the setup script where the computers can read it
1. On a server/PC, open this link and **Save As** the file
   `provision-station.ps1` into the **NETLOGON** share:
   `\\mrg.local\NETLOGON\provision-station.ps1`
   Download: https://github.com/MasterVision1/mrg-cert-labels/raw/main/scripts/provision-station.ps1

## Step 2 — Open Group Policy Management
2. Press **Win+R**, type `gpmc.msc`, Enter.

   **"Windows cannot find gpmc.msc"?** That console isn't on normal PCs — only on the
   **server (domain controller)**. Easiest: log into the **server** that runs `mrg.local`
   and run `gpmc.msc` there (it's already installed). *Or* add it to this PC with an
   **admin** PowerShell:
   `Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0`
   then try `gpmc.msc` again.
3. Find the folder (OU) that holds the **shop/station computers**. Right-click it →
   **Create a GPO in this domain, and Link it here…** → name it **`Cert Label Station`** → OK.
   *(If the station PCs aren't in their own folder, you can right-click the domain root
   instead — it just applies to all PCs.)*
4. Right-click the new **Cert Label Station** policy → **Edit**.

## Step 3 — Tell it to run the script at startup
5. In the editor, expand:
   **Computer Configuration → Policies → Windows Settings → Scripts (Startup/Shutdown)**.
6. Double-click **Startup** → click the **PowerShell Scripts** tab → **Add** → **Browse** →
   type `\\mrg.local\NETLOGON\provision-station.ps1` → **Open** → **OK** → **OK**.
7. Close the editor.

## Step 4 — Apply it
8. **Restart each shop computer twice** (or just leave them to reboot overnight; the
   policy runs every boot and skips work that's already done). First boot installs DYMO +
   sets everything; the auto-start is live from the next login on.

**That's it.** From now on, anyone logs into any station, opens the Cert Label Station,
and it just prints. No admin prompts, no "allow the connection," nothing.

---

## How to check one station worked
Log in as a **normal (non-admin) user**, open the Cert Label Station — it should say
**DYMO ready**. (Or paste `https://127.0.0.1:41951/DYMO/DLS/Printing/StatusConnected`
into Edge — it should say `true`.)

## If one stubborn PC won't auto-install DYMO
Rare, but if a machine's DYMO install doesn't take from the policy, sit at that PC once,
open PowerShell, paste this, click **Yes**, restart:
```
irm https://github.com/MasterVision1/mrg-cert-labels/raw/main/scripts/provision-station.ps1 | iex
```
Everything else (the all-users fix) still comes from the Group Policy.

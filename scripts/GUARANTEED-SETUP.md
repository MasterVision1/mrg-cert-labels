# Cert Label Station — guaranteed setup (do once per station)

This is the can't-fail method. Run it once on each printing PC. It works for **every
user** on that PC (admin or normal), and it sticks across restarts. ~5 minutes.

You log in as an admin (or have the admin password handy for the prompt in Step 1).

---

## Step 1 — Open PowerShell as Administrator
1. Click **Start**.
2. Type: `powershell`
3. **Right-click** "Windows PowerShell" → **Run as administrator** → **Yes**.
4. You should now have a window whose title bar starts with **"Administrator:"**.
   *(If the title does NOT say Administrator, close it and redo this step — this is the
   #1 reason setup fails.)*

## Step 2 — Paste this ONE line and press Enter
Copy this exactly (it's one line), right-click in the blue window to paste, press Enter:

```
[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://github.com/MasterVision1/mrg-cert-labels/raw/main/scripts/provision-station.ps1 | iex
```

## Step 3 — Let it run
- If a **DYMO installer window** appears, click through it (Next → Install → Finish).
- Wait until the PowerShell window prints **DONE** in green and asks you to press Enter.

## Step 4 — Restart the computer
The "start for every user" setting goes live at the next login.

## Step 5 — Confirm
Log in as a **normal (non-admin) user**, open the **Cert Label Station**. It should show
**DYMO ready** at the top — no prompts. Print a test label. Done.

---

## Did it work? Two quick checks (as the normal user)
- The app's header says **DYMO ready** (green), not "Connect DYMO".
- Or paste `https://127.0.0.1:41951/DYMO/DLS/Printing/StatusConnected` into Edge — it says `true`.

## If anything goes sideways
Re-run Step 2 in the Administrator window — it's safe to run again and tells you exactly
what it did or what's missing. Copy that text and send it over.

---

## Want it pushed to ALL computers automatically instead?
That's the Group Policy route in `EASY-SETUP-FOR-KEITH.md` (one policy, set once on the
server). Use this per-station method first to prove it works; move to Group Policy when
you have enough machines that running it per-PC is annoying.

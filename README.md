# MRG Cert Label Station

A shop-floor Static Web App for printing material cert / heat-number stickers on a
local DYMO LabelWriter — no more re-typing the same data into the DYMO app.

## How it works

1. **Troy approves a cert packet** in the purchasing-bot review flow. The approved
   packet (PO, heat #, material, spec, size, qty, part) becomes a "ready to print" label.
2. **An operator opens this app** on the computer that has the DYMO plugged in.
3. They see the list of approved-but-unprinted certs (newest first), can search all
   certs for reprints, **multi-select**, and hit **Print selected**.
4. The browser talks straight to the **DYMO Connect Web Service** on `127.0.0.1:41951`
   on that same machine — the sticker prints right there. Printed certs drop off the
   "Ready" list automatically.

The cloud app → local printer path works because the DYMO web service answers any
origin (`Access-Control-Allow-Origin: *`) and `127.0.0.1` always resolves to the
machine the browser is running on. No agent, no central print server, no barcode scanner.

## Per-station setup (one-time, run ONCE as admin — then every user is set)

On each machine that **prints**, an admin runs this once in an elevated PowerShell:

```
irm https://raw.githubusercontent.com/MasterVision1/mrg-cert-labels/main/scripts/provision-station.ps1 | iex
```

It installs DYMO Connect, **makes its web service auto-start for every user** (HKLM Run —
fixes "works as admin, standard user can't connect": DYMO normally auto-starts the
service from the *installing user's* HKCU, so other users never get it), trusts the cert
machine-wide, and verifies. After that, **any** user — admin or standard — just plugs in
the DYMO LabelWriter and prints, with no admin prompts and no per-user steps.

Already-installed station that only needs the connection fixed for non-admin users? The
same script is safe to re-run, or use `scripts/trust-dymo-cert.ps1` (per-user, no admin).

Machines that only view/approve need nothing but a browser.

## Wiring (status)

- **Front-end** — this repo. Runs standalone with embedded demo data when the backend
  is unreachable, so it always renders.
- **Backend** — `/api/labels` (GET, list approved certs) and `/api/labels/printed`
  (POST, mark printed) are served by the MRG purchasing-bot Functions app
  (`mrg-purchasing-fn`). Set `CONFIG.apiBase` in `index.html` to that host once the
  endpoints are deployed. See `azure-functions/purchasing-bot` in MRG-sandbox.

## DYMO capabilities (all validated against the live DYMO Connect service)

- **WYSIWYG preview** — the review modal renders the label with DYMO's own engine
  (`RenderLabel`), so what you see is exactly what prints (HTML mock as fallback
  when the service isn't reachable).
- **Label sizes** — Multipurpose 2¼×1¼ (30334, default), Address (30252), Large
  Address (30321), Shipping (30256), Return Address (30330). Each `Id`/`PaperName`
  was confirmed to render. Pick in Print Settings.
- **Barcode** — optional Code128 of the Heat # or PO #, for downstream scanning.
- **Copies** — 1–50 per cert.
- **Printer select** — auto-detects connected DYMO printers; multi-printer dropdown.

Note: the built-in sizes print correctly, but the shop's real tag is a 2-up wrap
label. For a pixel-perfect match, design it once in DYMO Connect and paste the XML
into `CONFIG.labelTemplateXml` (named objects PART/PO/MATERIAL/SIZE/HEAT/QTY are
merged in). Physical print still needs one confirmation on a real station.

## Label format

```
{partNumber} PO:{poNumber}
{material} {spec} {size}
HT#{heat} QTY {quantity}
```

The DYMO label XML in `index.html` (`buildLabelXml`) is a placeholder sized for a
30334 2-1/4" × 1-1/4" label. Design the real master tag once in DYMO Connect to match
the shop's actual label stock, then paste its `<DieCutLabel>` block in.

## Deploy

Auto-deploys to Azure Static Web Apps (MRG tenant) on push to `main` via
`.github/workflows/azure-static-web-apps.yml`.

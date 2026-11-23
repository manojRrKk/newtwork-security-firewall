# Full Setup Guide — Run this project on another computer

This guide takes a **completely fresh laptop or desktop** (Windows, macOS, or Linux) to a running
Network Security Lab console in about 10 minutes. No prior experience assumed. Everything runs
locally in **Demo Mode** — it does **not** send any network attack traffic and does **not** need
pfSense, Kali, or any VMs. (Turning on real Lab Mode is optional and covered at the end.)

---

## 0. What you will end up with

- A backend API running at **http://localhost:4000**
- A web console running at **http://localhost:5173** (this is the page you open)
- A local database file (`backend/data/lab.sqlite`) created automatically
- Login: `admin@lab.local` / `ChangeMe!123`

You only need a terminal and a web browser.

---

## 1. System requirements

| | Minimum |
|---|---|
| OS | Windows 10/11, macOS 12+, or a modern Linux |
| Node.js | **24 LTS or newer** (18 is too old; 22.x works only with an extra flag — see note) |
| RAM | 4 GB free |
| Disk | ~500 MB (mostly `node_modules`) |
| Internet | Needed **once** for `npm install`. After that the app runs offline.\* |

> \* The UI loads two web fonts from Google Fonts for polish. With no internet they simply fall
> back to system fonts — the app still works fully.

**Why Node 24+?** The backend uses Node's built-in SQLite (`node:sqlite`), which is stable and
enabled by default from Node 24 onward — so there is **no database to install and nothing to
compile**. (On Node 22.5–23.x it exists but is experimental; see Troubleshooting if you must use
22.x.)

---

## 2. Install Node.js

Check whether you already have a suitable version:

```bash
node -v
```

If it prints `v24.x.x`, `v26.x.x`, or higher, skip to step 3. Otherwise install it:

### Windows
1. Go to <https://nodejs.org> and download the **LTS** installer (24.x or newer).
2. Run it, accept defaults, finish.
3. Open a **new** terminal (PowerShell or Git Bash) and confirm: `node -v` and `npm -v`.

### macOS
- Easiest: download the LTS `.pkg` from <https://nodejs.org> and install, **or**
- With Homebrew: `brew install node@24` (then follow brew's PATH hint).

### Linux (Debian/Ubuntu)
```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Any OS with nvm (optional, nice)
This repo has a `.nvmrc`, so if you use nvm:
```bash
nvm install    # reads .nvmrc → installs Node 24
nvm use
```

---

## 3. Copy the project onto the machine

Use **either** method.

### Option A — copy the folder (USB, network share, zip)
Copy the whole `Network Security Lab` folder to the new computer.

> **Important:** do **not** copy the `node_modules` folders. They contain a binary built for the
> original machine's OS/CPU and can break on a different one. If they came along, delete every
> `node_modules` folder before continuing — step 4 rebuilds them correctly.

### Option B — Git
If you push this repo to GitHub/GitLab:
```bash
git clone <your-repo-url> "Network Security Lab"
```
(`node_modules` is already in `.gitignore`, so a clone is clean.)

---

## 4. Install dependencies + create the database

Open a terminal **in the project's root folder** (the one containing `package.json` and this
`docs/` folder), then run one command:

```bash
npm run setup
```

This runs `npm install` (all three workspaces) and then creates + seeds the local database. You
should see the migration and seed messages, ending with `Seed complete.`

> Prefer two steps? `npm install` then `npm run db:setup` does the same thing.

### Windows path note
If your folder name has a space (e.g. `Network Security Lab`), that's fine — just make sure you
`cd` into it with quotes:
```powershell
cd "S:\Projects\Network Security Lab"
```

---

## 5. Start the app

```bash
npm run dev
```

Wait a few seconds until you see both servers report ready:

```
[API] Network Security Lab API   http: http://localhost:4000/api
[WEB] VITE vX.Y.Z  ready         Local: http://localhost:5173/
```

Leave this terminal open — it is running the servers.

---

## 6. Open it and log in

1. Open a browser to **http://localhost:5173**
2. Sign in with:

| Role | Email | Password |
|---|---|---|
| Admin (can run tests) | `admin@lab.local` | `ChangeMe!123` |
| Analyst | `analyst@lab.local` | `Analyst!123` |
| Viewer (read-only) | `viewer@lab.local` | `Viewer!123` |

3. Follow [`demo-script.md`](demo-script.md) for the 10-step walkthrough (baseline → flood →
   enable firewall rule → re-run → before/after report).

---

## 7. Stop the app

In the terminal running `npm run dev`, press **Ctrl + C** (on Windows, confirm with `Y` if asked).
Both servers stop. Your data is kept in `backend/data/lab.sqlite`.

---

## 8. Running it again later

```bash
npm run dev
```
That's it — you don't reinstall or re-seed. To wipe the database back to a fresh demo state:
```bash
npm run db:reset
```

---

## 9. Optional: a production-style run

Dev mode (step 5) is perfect for a viva. If you want an optimized build of the console:

```bash
npm run build                 # builds frontend/dist
npm -w backend start          # start the API (http://localhost:4000)
npm -w frontend run preview   # serve the built console (prints a local URL)
```

(For a demo, `npm run dev` is simpler and recommended.)

---

## 10. Troubleshooting

**`node -v` shows v18 or lower, or the backend crashes with a `node:sqlite` / "experimental" error**
Install Node **24 LTS or newer** (step 2). If you are stuck on Node 22.x, start the backend with
the experimental flag instead:
`cross-env NODE_OPTIONS=--experimental-sqlite` — simplest is just to upgrade Node.

**`npm install` warns about "install scripts not yet covered by allowScripts" (npm 11)**
This is npm blocking `esbuild`'s post-install. It usually still works. If `npm run dev` then fails
with an esbuild/binary error, run:
```bash
npm rebuild esbuild
```
or approve it: `npm approve-scripts esbuild` then `npm install` again.

**Port 4000 or 5173 already in use**
Something else is using the port. Either close that program, or change the port:
- API: create `backend/.env` with `PORT=4001` (and it still proxies fine), or
- Web: edit `server.port` in `frontend/vite.config.ts`.
Find/stop the process using a port:
- Windows: `netstat -ano | findstr :5173` then `taskkill /PID <pid> /F`
- macOS/Linux: `lsof -i :5173` then `kill <pid>`

**The browser page is blank / won't load**
Make sure `npm run dev` is still running and shows no errors, then hard-refresh (Ctrl+F5). Confirm
the API is alive: open <http://localhost:4000/api/health> — it should return `{"status":"ok",...}`.

**Login fails ("Invalid email or password")**
The database wasn't seeded. Run `npm run db:setup` (or `npm run db:reset`), then try again.

**Fonts look plain / console shows a Google Fonts request failed**
You're offline. Harmless — the app falls back to system fonts and works normally.

**Firewall/antivirus prompt on first run**
Node wants to listen on localhost. Allow it on **private** networks. Nothing is exposed to the
internet.

**Everything is confusing — reset from scratch**
Delete all `node_modules` folders and `backend/data/lab.sqlite`, then run `npm run setup` again.

---

## 11. Verify it's healthy (optional quick checks)

```bash
# API health
curl http://localhost:4000/api/health

# run the automated security tests
npm test
```

---

## 12. Going further: real Lab Mode (pfSense + Kali + victim)

Everything above is Demo Mode (simulated, safe, single machine). To run the lab against **real**
infrastructure on an **isolated** virtual network, follow [`pfsense-setup.md`](pfsense-setup.md).
That guide covers the VM layout, pfSense rules + SNMP/syslog/SSH telemetry, the Kali traffic
worker (disarmed by default), and the victim host. The console honestly shows
"Integration unavailable" for any live signal that isn't connected yet — it never fabricates data.

---

## Quick reference (copy/paste)

```bash
# one-time, on a fresh machine (Node 24+ already installed):
cd "path/to/Network Security Lab"
npm run setup

# every time you want to use it:
npm run dev
# → open http://localhost:5173  (admin@lab.local / ChangeMe!123)
# → Ctrl+C to stop

# housekeeping:
npm run db:reset      # fresh demo data
npm test              # run security tests
```

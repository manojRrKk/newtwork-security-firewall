# Lab-Mode Infrastructure Setup (pfSense · Kali · Victim)

Demo Mode needs none of this. Follow this guide only to run the lab against **real**
infrastructure. Build everything on an **isolated virtual network** with no route to the
internet or any production system.

## 1. Virtual network layout (VMware/VirtualBox/Proxmox)

Create two isolated (host-only / internal) networks:

| Network | Subnet | Members |
|---------|--------|---------|
| LAB-WAN | 10.10.10.0/24 | Kali (attacker), pfSense WAN |
| LAB-LAN | 192.168.10.0/24 | pfSense LAN, Victim, Monitoring (console host) |

| Host | Interface | IP |
|------|-----------|----|
| pfSense | WAN (em0) | 10.10.10.1 |
| pfSense | LAN (em1) | 192.168.10.1 |
| Kali (attacker) | eth0 | 10.10.10.10 |
| Victim | eth0 | 192.168.10.10 |
| Monitoring (runs this console) | eth0 | 192.168.10.20 |

> Disable pfSense's "Block private networks" on WAN for this lab, since the WAN side is itself
> RFC1918. This is safe **only** because the lab is isolated.

## 2. pfSense

1. **Interfaces** — assign WAN/LAN as above; set static IPs.
2. **Rules (Firewall → Rules)** — mirror the console's seeded set:
   - WAN: ALLOW ICMP `10.10.10.0/24 → 192.168.10.10`
   - WAN: ALLOW TCP `10.10.10.0/24 → 192.168.10.10:80,443`
   - WAN: **BLOCK** `10.10.10.0/24 → 192.168.10.10` — *this is the mitigation rule; keep it
     disabled until Test 03.*
   - LAN: ALLOW `192.168.10.0/24 → any`
3. **Logging** — enable logging on the mitigation rule so blocks appear in the filter log.

### Telemetry the console reads (the `PfSenseProvider` lab implementation)

| Signal | Mechanism | pfSense config |
|--------|-----------|----------------|
| Interface throughput / counters | **SNMP** (IF-MIB `ifHCInOctets`/`ifHCOutOctets`) | Services → SNMP: enable, set a read community |
| Allow/block events | **Remote syslog** (filterlog) | Status → System Logs → Settings → Remote Logging → send *Firewall events* to 192.168.10.20:5514 |
| System status & rules | **SSH** `pfctl -si`, `pfctl -sr` | System → Advanced → enable Secure Shell; add the console's public key |

Fill the matching values in `backend/.env` (`PFSENSE_HOST`, `PFSENSE_SNMP_COMMUNITY`,
`PFSENSE_SSH_USER`, `PFSENSE_SSH_KEY_PATH`, `PFSENSE_SYSLOG_PORT`) and implement the TODOs in
`backend/src/providers/lab/labPfSense.ts`. Until then the console honestly reports
"Integration unavailable".

## 3. Kali (attacker) — the simulation-controller

```bash
sudo apt update && sudo apt install -y hping3 nodejs npm
git clone <this repo> && cd network-security-lab/simulation-controller
npm install

# Dry-run first (no packets) to verify the commands:
SC_TARGET_ALLOWLIST=192.168.10.0/24 SC_SHARED_SECRET=<random> npm start

# When satisfied, arm it (root needed for raw sockets):
sudo SC_TARGET_ALLOWLIST=192.168.10.0/24 SC_SHARED_SECRET=<random> SC_ARMED=1 npm start
```

The worker refuses any target outside `SC_TARGET_ALLOWLIST`, caps rate/duration, and kills
runaway jobs. See `simulation-controller/README.md`.

## 4. Victim

- A Linux or Windows host at 192.168.10.10 running a small service (e.g. a web server) so
  latency/availability are measurable.
- Optional: `iperf3 -s` for throughput baselining.

## 5. Console (Monitoring host)

```bash
cd network-security-lab
cp .env.example backend/.env      # set LAB_MODE=lab and the PFSENSE_* values
npm install && npm run db:setup
npm run dev
```

Switch the top-bar to **Lab Mode** (Settings) once telemetry is connected. Values with no live
source render as `N/A` / `Integration unavailable` — never fabricated.

## 6. Safety checklist

- [ ] Lab networks are isolated (no internet, no bridge to production).
- [ ] `SC_TARGET_ALLOWLIST` and `LAB_TARGET_ALLOWLIST` contain only the LAN subnet.
- [ ] `JWT_SECRET` and `SC_SHARED_SECRET` changed from defaults.
- [ ] The Kali worker starts **disarmed**; arm it only for a controlled run.
- [ ] Mitigation rule starts disabled; enable it only for Test 03.

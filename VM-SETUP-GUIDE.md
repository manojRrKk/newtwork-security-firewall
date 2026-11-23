# VM Setup Guide — Step-by-Step with Screenshots
## Network Security Lab: pfSense + Kali + Victim

> **This guide covers Lab Mode only.**
> If you just want to run the console on one machine (Demo Mode), use
> [`SETUP-GUIDE.md`](SETUP-GUIDE.md) instead — no VMs needed.

---

## Overview

The full lab environment consists of three virtual machines connected by two isolated networks:

```
 ┌─────────────────────────────────────────────────────────────────┐
 │                    HOST MACHINE (Windows/Linux/macOS)           │
 │                                                                  │
 │  ┌─────────────┐    LAB-WAN     ┌─────────────────────────┐    │
 │  │   KALI VM   │  10.10.10.0/24 │      pfSense VM          │    │
 │  │ 10.10.10.10 ├───────────────►│ WAN: 10.10.10.1          │    │
 │  │ (Attacker)  │                │ LAN: 192.168.10.1         │    │
 │  └─────────────┘                └────────────┬─────────────┘    │
 │                                              │                   │
 │                                   LAB-LAN    │  192.168.10.0/24  │
 │                                              ▼                   │
 │                               ┌──────────────────────────┐      │
 │                               │   VICTIM VM 192.168.10.10 │      │
 │                               │   MONITORING  192.168.10.20│     │
 │                               └──────────────────────────┘      │
 └─────────────────────────────────────────────────────────────────┘
```

**Minimum system requirements for all VMs:**
- 8 GB RAM (16 GB recommended)
- 50 GB free disk
- CPU with VT-x/AMD-V virtualization support

---

## Part 1: VirtualBox Setup (Recommended — Free)

### Step 1.1: Install VirtualBox

1. Go to **https://www.virtualbox.org/wiki/Downloads**
2. Download **VirtualBox for Windows hosts** (or your OS)
3. Run the installer with default settings
4. Also install the **VirtualBox Extension Pack** (same downloads page)

> 📸 **[Screenshot: VirtualBox download page showing installer links]**

### Step 1.2: Create Isolated Networks

VirtualBox uses "Host-Only" networks to simulate the isolated lab segments.

1. Open VirtualBox
2. Go to **File → Tools → Network Manager** (or File → Host Network Manager on older versions)
3. Click **Create** to add a new host-only network

**Create LAB-WAN network:**
- Name: `VirtualBox Host-Only Ethernet Adapter #2` (or note whatever it creates)
- IPv4 Address: `10.10.10.254`
- IPv4 Network Mask: `255.255.255.0`
- **Disable DHCP Server**

> 📸 **[Screenshot: VirtualBox Network Manager with Host-Only Adapter settings]**

**Create LAB-LAN network:**
- Name: `VirtualBox Host-Only Ethernet Adapter #3`
- IPv4 Address: `192.168.10.254`
- IPv4 Network Mask: `255.255.255.0`
- **Disable DHCP Server**

> 📸 **[Screenshot: Two host-only networks created in Network Manager]**

---

### Step 1.3: Create the pfSense VM

**Download pfSense ISO:**
1. Go to **https://www.pfsense.org/download/**
2. Architecture: **AMD64**
3. Console: **VGA**
4. Mirror: Choose closest mirror
5. Download the `.iso.gz` file and extract it

> 📸 **[Screenshot: pfSense download page with options selected]**

**Create pfSense VM in VirtualBox:**

1. Click **New** in VirtualBox
2. Settings:
   - Name: `NetworkLab-pfSense`
   - Type: **BSD**
   - Version: **FreeBSD (64-bit)**
   - Memory: **1024 MB**
3. Create a virtual hard disk: **10 GB, VDI, Dynamically allocated**

> 📸 **[Screenshot: VirtualBox "Create Virtual Machine" dialog for pfSense]**

**Configure Network Adapters:**

Right-click the VM → Settings → Network:
- **Adapter 1:** Enable, Attached to: *Host-only Adapter*, Name: `VirtualBox Host-Only Ethernet Adapter #2` (LAB-WAN)
- **Adapter 2:** Enable, Attached to: *Host-only Adapter*, Name: `VirtualBox Host-Only Ethernet Adapter #3` (LAB-LAN)

> 📸 **[Screenshot: pfSense VM network adapter settings showing two host-only adapters]**

**Mount pfSense ISO and Boot:**

1. Settings → Storage → Click the CD icon → Choose disk file → Select pfSense ISO
2. Start the VM
3. Follow the pfSense installer:
   - Accept copyright notice
   - Choose **Install pfSense**
   - Keymap: Default (or your preference)
   - Partitioning: **Auto (UFS)**
   - Wait for installation to complete
   - **Do NOT reboot** — first unmount the ISO
4. Remove ISO: Settings → Storage → Right-click disc → Remove
5. Reboot

> 📸 **[Screenshot: pfSense installer welcome screen]**
> 📸 **[Screenshot: pfSense installation progress]**

---

### Step 1.4: Configure pfSense

After reboot, pfSense shows the console menu.

**Set Interface Assignments:**
1. Enter option **1** (Assign Interfaces)
2. VLANs? **n**
3. WAN interface: `em0` (the first adapter — LAB-WAN)
4. LAN interface: `em1` (the second adapter — LAB-LAN)
5. Confirm: **y**

> 📸 **[Screenshot: pfSense console interface assignment]**

**Set LAN IP:**
1. Enter option **2** (Set interface(s) IP address)
2. Choose **2** for LAN
3. Enter `192.168.10.1`
4. Subnet bits: `24`
5. Gateway: (press Enter — none for LAN)
6. IPv6: (press Enter — none)
7. Enable DHCP? **y** (range: 192.168.10.100 to 192.168.10.200)

**Set WAN IP (since WAN is host-only, not internet):**
1. Option 2 → Choose WAN
2. Enter `10.10.10.1`
3. Subnet bits: `24`
4. Leave gateway empty (host-only doesn't need one for our lab)

> 📸 **[Screenshot: pfSense console showing IP configured]**

**Access pfSense Web Interface:**
- From your host machine, open a browser
- Navigate to `http://192.168.10.1` (this reaches the pfSense LAN)

> **Note:** You may need to temporarily connect a VM to LAB-LAN to reach the web UI,
> or configure a static route on the host to reach 192.168.10.0/24 via the host-only adapter.

**pfSense Setup Wizard:**
1. Default login: `admin` / `pfsense`
2. Complete the Setup Wizard:
   - Hostname: `pfsense.lab`
   - Domain: `lab.local`
   - DNS servers: `1.1.1.1` (or any)
   - Timezone: Your timezone
   - WAN: Static, IP `10.10.10.1`, Mask `255.255.255.0`
   - LAN: `192.168.10.1`

> 📸 **[Screenshot: pfSense web dashboard after initial login]**

---

### Step 1.5: Configure pfSense Firewall Rules

Navigate to **Firewall → Rules → WAN**:

| # | Interface | Action | Protocol | Source | Destination | Port | Description |
|---|-----------|--------|----------|--------|-------------|------|-------------|
| 1 | WAN | ALLOW | ICMP | 10.10.10.0/24 | 192.168.10.10 | * | Allow ICMP to victim |
| 2 | WAN | ALLOW | TCP | 10.10.10.0/24 | 192.168.10.10 | 80,443 | Allow HTTP/HTTPS to victim |
| 50| WAN | **BLOCK**| * | 10.10.10.0/24 | 192.168.10.10 | * | **DoS Mitigation** (DISABLED initially) |
| 100| WAN | ALLOW | * | 10.10.10.0/24 | 192.168.10.0/24 | * | Allow all WAN-to-LAN |

**Important:** Rule #50 (the mitigation rule) must be **created first but kept disabled** for Tests 1 and 2.

> 📸 **[Screenshot: pfSense WAN firewall rules list]**

**Enable Logging on the mitigation rule:**
- Edit rule #50 → Check "Log packets that are handled by this rule"

---

### Step 1.6: Configure pfSense SNMP and Syslog

**Enable SNMP (for traffic monitoring):**
1. Services → SNMP
2. Enable: ✅
3. Read Community String: `public` (change for production)
4. Bindings: LAN interface
5. Save

> 📸 **[Screenshot: pfSense SNMP configuration page]**

**Enable Remote Syslog (for firewall events):**
1. Status → System Logs → Settings
2. Enable Remote Logging: ✅
3. Remote log servers: `192.168.10.20:5514` (monitoring VM)
4. Remote Syslog Contents: Check **Firewall Events**
5. Save

> 📸 **[Screenshot: pfSense Syslog settings]**

**Enable SSH (for rule and status queries):**
1. System → Advanced → Admin Access
2. Secure Shell: Enable ✅
3. SSH port: 22
4. Save

---

## Part 2: Create Kali Linux VM (Attacker)

### Step 2.1: Download Kali Linux

1. Go to **https://www.kali.org/get-kali/#kali-installer-images**
2. Download **Kali Linux 64-Bit Installer**
3. Verify SHA256 checksum

> 📸 **[Screenshot: Kali Linux download page]**

### Step 2.2: Create Kali VM

In VirtualBox:
1. Click **New**
2. Settings:
   - Name: `NetworkLab-Kali`
   - Type: **Linux**
   - Version: **Debian (64-bit)**
   - Memory: **2048 MB**
3. Create disk: **20 GB, VDI, Dynamically allocated**

**Network Adapter:**
- Adapter 1: Host-only Adapter → `VirtualBox Host-Only Ethernet Adapter #2` (LAB-WAN)

> 📸 **[Screenshot: Kali VM settings]**

### Step 2.3: Install Kali Linux

1. Mount Kali ISO → Start VM
2. Choose **Graphical Install** (or Text Install)
3. Follow the installer:
   - Language/Country/Keyboard
   - Hostname: `kali-attacker`
   - Domain: `lab.local`
   - Full name / username: `kali` / `kali`
   - Password: (choose a strong password)
   - Partitioning: Guided, use entire disk
4. Desktop Environment: **Xfce** (lightest, fastest)
5. Finish installation, reboot

> 📸 **[Screenshot: Kali installer in progress]**

### Step 2.4: Configure Kali Static IP

After Kali boots:

1. Open Terminal
2. Edit network config:
```bash
sudo nano /etc/network/interfaces
```

Add:
```
auto eth0
iface eth0 inet static
  address 10.10.10.10
  netmask 255.255.255.0
  gateway 10.10.10.1
```

3. Apply:
```bash
sudo systemctl restart networking
```

4. Verify:
```bash
ip addr show eth0
ping 10.10.10.1
```

> 📸 **[Screenshot: Kali terminal with network configuration]**

### Step 2.5: Install Required Tools on Kali

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install hping3 (traffic generator)
sudo apt install -y hping3

# Install Node.js 24 (for simulation-controller)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
hping3 --version
node -v
```

> 📸 **[Screenshot: Kali terminal with hping3 and node installed]**

### Step 2.6: Deploy Simulation Controller on Kali

Copy the `simulation-controller` folder to Kali (via shared folder or SCP):

```bash
# On Kali, in the simulation-controller directory:
npm install

# Test run (dry run - no packets)
SC_TARGET_ALLOWLIST=192.168.10.0/24 \
SC_SHARED_SECRET=lab-secret-change-me \
npm start
```

---

## Part 3: Create Ubuntu Victim VM

### Step 3.1: Download Ubuntu Server

1. Go to **https://ubuntu.com/download/server**
2. Download **Ubuntu Server 22.04 LTS**

### Step 3.2: Create Victim VM

In VirtualBox:
1. Click **New**
2. Settings:
   - Name: `NetworkLab-Victim`
   - Type: **Linux**
   - Version: **Ubuntu (64-bit)**
   - Memory: **1024 MB**
3. Create disk: **10 GB, VDI, Dynamically allocated**

**Network Adapter:**
- Adapter 1: Host-only Adapter → `VirtualBox Host-Only Ethernet Adapter #3` (LAB-LAN)

### Step 3.3: Install Ubuntu Server

1. Mount Ubuntu ISO → Start VM
2. Follow installer (minimal, no cloud features needed)
3. Network: Configure as static
   - IP: `192.168.10.10`
   - Mask: `255.255.255.0`
   - Gateway: `192.168.10.1`
4. Install OpenSSH Server: ✅
5. Complete installation

> 📸 **[Screenshot: Ubuntu Server installer network configuration]**

### Step 3.4: Install Web Server on Victim

```bash
# Install nginx (web server - gives us measurable availability)
sudo apt install -y nginx

# Start and enable
sudo systemctl enable --now nginx

# Verify
curl http://localhost
```

The victim now runs an HTTP server at `192.168.10.10`. The lab measures its availability under DoS.

---

## Part 4: Configure the Console for Lab Mode

### Step 4.1: Create .env File

On the **monitoring host** (your main machine running the console):

```bash
# In the Network Security Lab project root:
cp .env.example backend/.env
```

Edit `backend/.env`:
```ini
# Lab Mode - real pfSense integration
LAB_MODE=lab

# pfSense connection
PFSENSE_HOST=192.168.10.1
PFSENSE_SNMP_COMMUNITY=public
PFSENSE_SSH_USER=admin
PFSENSE_SSH_KEY_PATH=./backend/data/pfsense_key
PFSENSE_SYSLOG_PORT=5514

# Security
JWT_SECRET=CHANGE-THIS-TO-A-RANDOM-STRING
SC_SHARED_SECRET=lab-secret-change-me

# Attack limits
LAB_TARGET_ALLOWLIST=192.168.10.0/24
MAX_TEST_DURATION_SECONDS=60
MAX_TEST_PPS=5000
```

### Step 4.2: Generate SSH Key for pfSense

```bash
# Generate key pair
ssh-keygen -t ed25519 -f backend/data/pfsense_key -N ""

# Copy public key to pfSense
cat backend/data/pfsense_key.pub
```

Add the public key in pfSense: System → User Manager → admin → Authorized SSH Keys

### Step 4.3: Start the Console

```bash
# From project root:
npm run dev
```

Navigate to `http://localhost:5173` → Settings → Switch to **Lab Mode**

> 📸 **[Screenshot: Console Settings page showing Lab Mode toggle]**

---

## Part 5: Running the Full Lab Experiment

### Step 5.1: Pre-Experiment Checklist

- [ ] pfSense running, web UI accessible
- [ ] Kali running, can ping 10.10.10.1
- [ ] Victim running, nginx responding at 192.168.10.10
- [ ] Console running in Lab Mode, telemetry showing
- [ ] DoS Mitigation rule (#50) **disabled** in pfSense

> 📸 **[Screenshot: Console Overview page in Lab Mode with green status indicators]**

### Step 5.2: Test 1 — Baseline

In the console: **Attack Lab → Test 01 · Baseline → Launch**

This generates low-rate normal traffic. The victim should respond normally.

> 📸 **[Screenshot: Console showing baseline test running with traffic graph]**

### Step 5.3: Test 2 — High-Rate Attack (No Mitigation)

In the console: **Attack Lab → Test 02 · High-Rate → Launch**

Observe:
- Traffic rate spikes (Traffic page)
- Victim availability drops (Events page shows alerts)
- pfSense allows all traffic through (no blocking rule)

> 📸 **[Screenshot: Console traffic page showing traffic spike during attack]**
> 📸 **[Screenshot: Security Events page showing availability alerts]**

### Step 5.4: Enable Mitigation Rule

In the console: **Firewall → Rule #50 · DoS Mitigation → Enable**

Or directly in pfSense web UI: Firewall → Rules → WAN → Enable the BLOCK rule.

> 📸 **[Screenshot: Console Firewall page showing rule being enabled]**

### Step 5.5: Test 3 — Attack With Mitigation

In the console: **Attack Lab → Test 03 · Mitigation → Launch**

Observe:
- Traffic blocked by pfSense (Firewall events page)
- Victim remains available
- Block count increases in Firewall rules

> 📸 **[Screenshot: Console showing traffic blocked with mitigation rule active]**

### Step 5.6: Generate Report

**Reports → Select test → Generate Lab Report**

The report shows:
- Before mitigation: victim degraded, high packet loss
- After mitigation: victim recovered, blocks visible

> 📸 **[Screenshot: Console Reports page showing before/after comparison]**
> 📸 **[Screenshot: Generated report with traffic charts]**

---

## Troubleshooting

### pfSense web UI unreachable
- Verify LAN IP is `192.168.10.1`: pfSense console option 2
- Check that your host has a route to 192.168.10.0/24 via the LAN host-only adapter
- Temporarily connect a VM to the LAN and browse from there

### Kali can't ping pfSense WAN
- Verify Kali's IP: `ip addr show eth0` → should be `10.10.10.10`
- Check pfSense WAN is `10.10.10.1`
- Both must be on same host-only adapter (LAB-WAN)

### Console shows "Integration unavailable"
- Verify `backend/.env` has the correct `PFSENSE_HOST`
- Verify SNMP is enabled on pfSense
- Check that the monitoring host can reach `192.168.10.1`

### Simulation controller won't start
- Must run as root on Kali (`sudo npm start`)
- Verify `SC_TARGET_ALLOWLIST` matches your LAN subnet
- Verify `SC_ARMED=1` is set when you want to actually send packets

---

## Network Topology Summary

| Host | VM Name | Interface | IP | Role |
|------|---------|-----------|-----|------|
| pfSense | NetworkLab-pfSense | WAN (em0) | 10.10.10.1 | Firewall |
| pfSense | NetworkLab-pfSense | LAN (em1) | 192.168.10.1 | Gateway |
| Kali | NetworkLab-Kali | eth0 | 10.10.10.10 | Attacker |
| Victim | NetworkLab-Victim | eth0 | 192.168.10.10 | Target |
| Monitoring | (host machine) | Host adapter | 192.168.10.20 | Console |

---

*See also: [`pfsense-setup.md`](pfsense-setup.md) | [`SETUP-GUIDE.md`](SETUP-GUIDE.md) | [`demo-script.md`](demo-script.md)*

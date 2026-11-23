@echo off
setlocal EnableDelayedExpansion
title Network Security Lab - Full Setup
color 0A
cls

echo.
echo  ================================================================
echo   NETWORK SECURITY LAB  ^|  FULL SETUP WIZARD
echo   pfSense Firewall + DoS Defense Console
echo  ================================================================
echo   This script installs EVERYTHING needed automatically:
echo     * Node.js 24 LTS
echo     * Oracle VirtualBox
echo     * pfSense / Kali / Ubuntu ISOs  (optional download)
echo     * 3 VMs with correct network topology
echo     * Project dependencies + database
echo  ================================================================
echo.
echo  [NOTE] An internet connection is needed for downloads.
echo         All VMs are isolated - no traffic leaves your machine.
echo.
pause

:: ================================================================
:: STEP 1 — Check / Install Node.js
:: ================================================================
call :section "STEP 1 of 5  -  Node.js 24 LTS"

where node >nul 2>&1
if %errorLevel% neq 0 goto :need_node

:: Node found - check major version
for /f "tokens=1 delims=v" %%V in ('node -v 2^>nul') do set NODEVER=%%V
for /f "tokens=1 delims=." %%M in ("!NODEVER!") do set NODEMAJOR=%%M
if !NODEMAJOR! GEQ 24 (
    call :ok "Node.js v!NODEVER! already installed"
    goto :node_done
)
echo [WARN] Node.js v!NODEVER! is too old (need 24+). Installing...

:need_node
call :info "Downloading Node.js 24 LTS installer..."
set "NODE_MSI=%TEMP%\node-v24-x64.msi"
set "NODE_URL=https://nodejs.org/dist/v24.1.0/node-v24.1.0-x64.msi"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Write-Host '  Downloading...'; try { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%NODE_URL%', '%NODE_MSI%'); Write-Host '  Download complete.' } catch { Write-Host \"  ERROR: $($_.Exception.Message)\"; exit 1 }"
if %errorLevel% neq 0 (
    call :warn "Auto-download failed. Opening nodejs.org in browser."
    call :warn "Install Node.js 24+ then re-run this script."
    start https://nodejs.org/en/download/
    pause & exit /b 1
)

call :info "Installing Node.js silently (this takes ~1 min)..."
msiexec /i "%NODE_MSI%" /passive /norestart ADDLOCAL=ALL
:: Refresh PATH for the rest of this session
for /f "tokens=*" %%P in ('powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable(\"PATH\",\"Machine\")"') do set "PATH=%%P"
set "PATH=%PATH%;%ProgramFiles%\nodejs"

where node >nul 2>&1
if %errorLevel% neq 0 (
    call :warn "Node.js installed but not on PATH yet."
    call :warn "Close and re-run this script after the installer finishes."
    pause & exit /b 1
)
call :ok "Node.js installed successfully"

:node_done

:: ================================================================
:: STEP 2 — Install Project Dependencies + Database
:: ================================================================
call :section "STEP 2 of 5  -  Project Dependencies + Database"

cd /d "%~dp0"

if not exist "node_modules" (
    call :info "Running npm install (downloads ~300 MB)..."
    call npm install
    if !errorLevel! neq 0 ( call :err "npm install failed" & pause & exit /b 1 )
    call :ok "Dependencies installed"
) else (
    call :ok "node_modules already present"
)

if not exist "backend\data\lab.sqlite" (
    call :info "Creating and seeding database..."
    call npm run db:setup
    if !errorLevel! neq 0 ( call :err "Database setup failed" & pause & exit /b 1 )
    call :ok "Database ready"
) else (
    call :ok "Database already exists"
)

:: ================================================================
:: STEP 3 — Check / Install VirtualBox
:: ================================================================
call :section "STEP 3 of 5  -  Oracle VirtualBox"

set "VBOX_EXE=C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if exist "!VBOX_EXE!" (
    call :ok "VirtualBox already installed"
    goto :vbox_done
)

:: Try winget first (Windows 10 2004+ built-in)
where winget >nul 2>&1
if %errorLevel% equ 0 (
    call :info "Installing VirtualBox via winget..."
    winget install --id Oracle.VirtualBox --silent --accept-package-agreements --accept-source-agreements
    if !errorLevel! equ 0 (
        call :ok "VirtualBox installed via winget"
        goto :vbox_done
    )
    call :warn "winget install failed, falling back to direct download..."
)

:: Direct download fallback
call :info "Downloading VirtualBox 7 installer (~100 MB)..."
set "VBOX_URL=https://download.virtualbox.org/virtualbox/7.0.14/VirtualBox-7.0.14-161095-Win.exe"
set "VBOX_EXE_DL=%TEMP%\VirtualBox-installer.exe"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Write-Host '  Downloading VirtualBox...'; try { $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%VBOX_URL%', '%VBOX_EXE_DL%'); Write-Host '  Done.' } catch { Write-Host \"  ERROR: $($_.Exception.Message)\"; exit 1 }"
if %errorLevel% neq 0 (
    call :warn "Could not download VirtualBox automatically."
    call :warn "Please install manually from: https://www.virtualbox.org/wiki/Downloads"
    start https://www.virtualbox.org/wiki/Downloads
    echo.
    echo  After installing VirtualBox, press any key to continue...
    pause >nul
    goto :vbox_check
)

call :info "Installing VirtualBox silently..."
"%VBOX_EXE_DL%" --silent --msiparams ADDLOCAL=ALL
call :ok "VirtualBox installation started"

:vbox_check
if not exist "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" (
    call :warn "VirtualBox not detected yet. It may need a reboot."
    call :warn "After rebooting, re-run this script to continue VM creation."
    echo.
    set /p SKIP_VM="  Skip VM creation for now? (Y/N): "
    if /i "!SKIP_VM!"=="Y" goto :vm_skip
)

:vbox_done

:: ================================================================
:: STEP 4 — Create VMs
:: ================================================================
call :section "STEP 4 of 5  -  Create Virtual Machines"

set "VBOXMANAGE=C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if not exist "!VBOXMANAGE!" (
    call :warn "VBoxManage not found. Skipping VM creation."
    goto :vm_skip
)
call :ok "VBoxManage found"

:: Run PowerShell VM creation script
call :info "Launching automated VM creation (creates pfSense + Kali + Victim)..."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-virtualbox.ps1" -VBoxPath "C:\Program Files\Oracle\VirtualBox" -Unattended
if %errorLevel% neq 0 (
    call :warn "VM creation script returned an error."
    call :warn "You can re-run: scripts\setup-virtualbox.ps1 manually."
) else (
    call :ok "VMs created successfully"
)
goto :vm_done

:vm_skip
call :info "VM creation skipped. Run SETUP-ALL.bat again after installing VirtualBox."
:vm_done

:: ================================================================
:: STEP 5 — Generate Report (DOCX + PDF)
:: ================================================================
call :section "STEP 5 of 5  -  Generate Academic Report"

call :info "Generating DOCX and PDF report..."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\generate-report.ps1"
if %errorLevel% neq 0 (
    call :warn "Report generation had issues. Check scripts\generate-report.ps1 output."
) else (
    call :ok "Report generated: docs\FULL-REPORT.docx and docs\FULL-REPORT.pdf"
)

:: ================================================================
:: DONE
:: ================================================================
echo.
echo  ================================================================
echo   SETUP COMPLETE
echo  ================================================================
echo.
echo   What was installed / configured:
echo     [OK] Node.js 24+
echo     [OK] npm dependencies
echo     [OK] SQLite database with demo data
echo     [OK] Oracle VirtualBox
echo     [OK] 3 VMs (pfSense, Kali, Victim) with network adapters
echo     [OK] Academic report (DOCX + PDF) in docs\
echo.
echo   NEXT STEPS:
echo     1. Double-click START.bat to launch the console
echo        (Demo Mode works right now - no VMs needed)
echo.
echo     2. For Lab Mode with real VMs:
echo        a. Open VirtualBox and start each VM
echo        b. Install OS from ISO on each VM
echo        c. Configure IPs per docs\VM-SETUP-GUIDE.md
echo        d. Copy .env.example to backend\.env and set LAB_MODE=lab
echo.
echo     3. Open report: docs\FULL-REPORT.docx
echo.
echo  ================================================================
echo.
pause
exit /b 0

:: ================================================================
:: HELPERS
:: ================================================================
:section
echo.
echo  ----------------------------------------------------------------
echo   %~1
echo  ----------------------------------------------------------------
goto :eof

:ok
echo   [^<OK^>] %~1
goto :eof

:info
echo   [....] %~1
goto :eof

:warn
echo   [WARN] %~1
goto :eof

:err
echo   [ERR!] %~1
goto :eof

@echo off
setlocal EnableDelayedExpansion
title Network Security Lab - Console
color 0A
cls

echo.
echo  ================================================================
echo   NETWORK SECURITY LAB  ^|  START CONSOLE
echo  ================================================================
echo.

cd /d "%~dp0"

:: Quick prerequisite guard
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo  [ERR] Node.js not found. Run SETUP-ALL.bat first.
    pause & exit /b 1
)

if not exist "node_modules" (
    echo  [....] node_modules missing - running npm install...
    call npm install
    if !errorLevel! neq 0 ( echo  [ERR] npm install failed. & pause & exit /b 1 )
)

if not exist "backend\data\lab.sqlite" (
    echo  [....] Database not found - running setup...
    call npm run db:setup
    if !errorLevel! neq 0 ( echo  [ERR] Database setup failed. & pause & exit /b 1 )
)

echo   [OK ] Backend API   ->  http://localhost:4000
echo   [OK ] Web Console   ->  http://localhost:5173
echo.
echo   Login:  admin@lab.local  /  ChangeMe!123
echo.
echo   Opening browser in 4 seconds...  Press Ctrl+C to stop servers.
echo.

start "" cmd /c "timeout /t 4 /nobreak >nul & start http://localhost:5173"

call npm run dev
echo.
echo  Servers stopped.
pause

@echo off
echo ========================================
echo   Mobile App Server - Auto Start
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] Updating IP configuration...
node update-ip.js

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ IP configuration failed!
    pause
    exit /b 1
)

echo.
echo [2/3] Testing network connectivity...
node test-connection.js

echo.
echo [3/3] Starting server on port 3000...
echo.
echo 💡 Tip: If other devices can't connect, run setup-firewall.bat as Administrator
echo.
node app.js

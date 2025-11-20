@echo off
echo ========================================
echo   Mobile App Server - Auto Start
echo ========================================
echo.

cd /d "%~dp0"

echo [1/2] Updating IP configuration...
node update-ip.js

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ IP configuration failed!
    pause
    exit /b 1
)

echo.
echo [2/2] Starting server...
echo.
node app.js

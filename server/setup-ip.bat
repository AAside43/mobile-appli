@echo off
echo ========================================
echo   Auto IP Configuration Tool
echo ========================================
echo.

cd /d "%~dp0"

echo [1/2] Detecting your PC's IP address...
node update-ip.js

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   Configuration Complete!
    echo ========================================
    echo.
    echo Next steps:
    echo 1. Start the server: node app.js
    echo 2. Restart your Flutter app
    echo.
    pause
) else (
    echo.
    echo ❌ Configuration failed!
    pause
    exit /b 1
)

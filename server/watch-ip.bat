@echo off
echo ========================================
echo   IP Auto-Update Monitor
echo ========================================
echo.
echo This will monitor your network and
echo automatically update config.dart when
echo your IP address changes.
echo.
echo Press Ctrl+C to stop monitoring.
echo.
echo ========================================
echo.

cd /d "%~dp0"
node update-ip.js --watch

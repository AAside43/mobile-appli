@echo off
echo ========================================
echo   Setup Windows Firewall for Port 3000
echo ========================================
echo.
echo This will allow other devices to connect
echo to your server on port 3000.
echo.
echo Note: Requires Administrator privileges
echo.
pause

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ✅ Running with Administrator privileges
    echo.
) else (
    echo ❌ ERROR: Please run as Administrator
    echo Right-click this file and select "Run as administrator"
    pause
    exit /b 1
)

echo [1/3] Removing old firewall rule (if exists)...
netsh advfirewall firewall delete rule name="Mobile App Server - Port 3000" >nul 2>&1

echo [2/3] Adding new firewall rule for inbound connections...
netsh advfirewall firewall add rule name="Mobile App Server - Port 3000" dir=in action=allow protocol=TCP localport=3000

if %errorLevel% == 0 (
    echo ✅ Firewall rule added successfully!
) else (
    echo ❌ Failed to add firewall rule
    pause
    exit /b 1
)

echo [3/3] Adding firewall rule for outbound connections...
netsh advfirewall firewall add rule name="Mobile App Server - Port 3000 (Out)" dir=out action=allow protocol=TCP localport=3000

echo.
echo ========================================
echo ✅ Firewall Setup Complete!
echo ========================================
echo.
echo Port 3000 is now open for:
echo   - Incoming connections (other devices → this PC)
echo   - Outgoing connections (this PC → other devices)
echo.
echo You can now connect from other devices on
echo the same Wi-Fi network!
echo.
pause

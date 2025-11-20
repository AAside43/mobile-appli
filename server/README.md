# Server Quick Start Guide

## 🚀 Start Server (Recommended)

Just double-click: **`start-server.bat`**

This will:
1. Auto-detect your PC's IP
2. Update Flutter configuration
3. Start the server

## 📝 Manual IP Update

If you need to update IP without starting server:
```cmd
setup-ip.bat
```

## 📡 Check Server IP

While server is running, visit:
- http://localhost:3000/server-ip

## 🔧 Troubleshooting

### Can't connect from phone?
1. Run `start-server.bat` again
2. Make sure phone and PC are on same WiFi
3. Check Windows Firewall (allow port 3000)

### Wrong IP detected?
Check your PC's IP:
```cmd
ipconfig
```
Look for "IPv4 Address" under your WiFi adapter

### Server won't start?
1. Check if MySQL is running
2. Verify port 3000 is not in use
3. Check `db.js` configuration

## 📱 Your Current IP

After running the server, check the console output for:
```
📱 Use this URL in your Flutter app: http://YOUR_IP:3000
```

## 🌐 Network Types

- **Same WiFi**: Use auto-detected IP
- **Android Emulator**: Automatically uses 10.0.2.2
- **iOS Simulator**: Uses localhost

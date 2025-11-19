# Auto IP Configuration for Mobile App

This tool automatically detects your PC's IP address and updates the Flutter configuration.

## Quick Start

### Windows
Simply run:
```cmd
setup-ip.bat
```

### Manual (Node.js)
```cmd
cd server
node update-ip.js
```

## What It Does

1. **Detects your PC's local IP address** (e.g., 192.168.1.100)
2. **Updates `lib/config.dart`** with the detected IP
3. **Configures the server** to show the correct connection URL

## Usage

### Every time your IP changes (e.g., different WiFi network):

1. Run `setup-ip.bat` in the `server` folder
2. Start the server: `node app.js`
3. Restart your Flutter app

### First Time Setup

1. Make sure Node.js is installed
2. Navigate to the server folder
3. Run: `setup-ip.bat`
4. Start server: `node app.js`

## Server Features

The server now automatically:
- Detects its own IP on startup
- Shows the IP in console logs
- Provides `/server-ip` endpoint for manual checks

### Check Server IP
Visit: `http://localhost:3000/server-ip`

Response:
```json
{
  "ip": "192.168.1.100",
  "port": 3000,
  "url": "http://192.168.1.100:3000"
}
```

## Troubleshooting

### IP not detected correctly
- Check if you're connected to a network
- Try running as administrator
- Manually set IP in `lib/config.dart`:
  ```dart
  const String _defaultHost = 'YOUR_IP_HERE';
  ```

### Flutter app can't connect
1. Make sure server is running
2. Check firewall settings (allow port 3000)
3. Verify both devices are on the same network
4. Run `setup-ip.bat` again

### Server shows 0.0.0.0
- This means no network interface detected
- Connect to WiFi/Ethernet and restart server

## Manual Configuration

If auto-detection doesn't work, edit `lib/config.dart`:

```dart
const String _defaultHost = '192.168.1.XXX'; // Your PC's IP
const int _port = 3000;
```

Find your IP:
- Windows: `ipconfig` (look for IPv4 Address)
- Mac/Linux: `ifconfig` or `ip addr`

## Network Requirements

- PC and mobile device must be on the **same WiFi network**
- Firewall must allow connections on port 3000
- For Android emulator, uses `10.0.2.2` automatically

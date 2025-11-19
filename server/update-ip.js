const fs = require('fs');
const path = require('path');
const os = require('os');

// Get local IP address
function getLocalIPAddress() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            // Skip internal (loopback) and non-IPv4 addresses
            if (iface.family === 'IPv4' && !iface.internal) {
                return iface.address;
            }
        }
    }
    return '127.0.0.1';
}

// Update config.dart file
function updateConfigFile() {
    const localIP = getLocalIPAddress();
    const configPath = path.join(__dirname, '..', 'lib', 'config.dart');
    
    console.log(`📡 Detected IP Address: ${localIP}`);
    console.log(`📝 Updating config file: ${configPath}`);
    
    try {
        let content = fs.readFileSync(configPath, 'utf8');
        
        // Update the _defaultHost value
        const updatedContent = content.replace(
            /const String _defaultHost = '[^']*';/,
            `const String _defaultHost = '${localIP}';`
        );
        
        // Also update Android emulator IP if needed
        const finalContent = updatedContent.replace(
            /if \(Platform\.isAndroid\) return 'http:\/\/[^']*';/,
            `if (Platform.isAndroid) return 'http://${localIP}:$_port';`
        );
        
        fs.writeFileSync(configPath, finalContent, 'utf8');
        
        console.log(`✅ Config updated successfully!`);
        console.log(`📱 Flutter app will connect to: http://${localIP}:3000`);
        console.log(`\n🔄 Run "flutter pub get" if needed, then restart your app.`);
        
    } catch (error) {
        console.error('❌ Error updating config file:', error.message);
        process.exit(1);
    }
}

// Run the update
updateConfigFile();

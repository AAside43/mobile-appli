const fs = require('fs');
const path = require('path');
const os = require('os');

// Get local IP address
function getLocalIPAddress() {
    const interfaces = os.networkInterfaces();
    const addresses = [];
    
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            // Skip internal (loopback) and non-IPv4 addresses
            if (iface.family === 'IPv4' && !iface.internal) {
                addresses.push(iface.address);
            }
        }
    }
    
    // Prefer non-VPN addresses (typically 192.168.x.x or 10.x.x.x)
    const preferred = addresses.find(addr => 
        addr.startsWith('192.168.') || addr.startsWith('10.')
    );
    
    return preferred || addresses[0] || '127.0.0.1';
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
        
        return localIP;
        
    } catch (error) {
        console.error('❌ Error updating config file:', error.message);
        process.exit(1);
    }
}

// Monitor for IP changes (for auto-update when location changes)
function monitorIPChanges(interval = 10000) {
    let currentIP = getLocalIPAddress();
    
    console.log(`\n🔍 Monitoring network changes (checking every ${interval/1000}s)...`);
    console.log(`📍 Current IP: ${currentIP}\n`);
    
    setInterval(() => {
        const newIP = getLocalIPAddress();
        if (newIP !== currentIP && newIP !== '127.0.0.1') {
            console.log(`\n⚠️  Network change detected!`);
            console.log(`   Old IP: ${currentIP}`);
            console.log(`   New IP: ${newIP}`);
            currentIP = updateConfigFile();
        }
    }, interval);
}

// Run the update
const runMode = process.argv[2];

if (runMode === '--watch') {
    // Watch mode: update once then monitor for changes
    updateConfigFile();
    monitorIPChanges(10000); // Check every 10 seconds
} else {
    // Single update mode
    updateConfigFile();
}

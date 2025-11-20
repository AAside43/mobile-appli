const os = require('os');
const http = require('http');

// Get local IP address
function getLocalIPAddress() {
    const interfaces = os.networkInterfaces();
    const addresses = [];
    
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                addresses.push({ name, address: iface.address });
            }
        }
    }
    
    return addresses;
}

// Test if port is accessible
function testPort(host, port) {
    return new Promise((resolve) => {
        const req = http.get(`http://${host}:${port}/server-ip`, (res) => {
            resolve({ success: true, status: res.statusCode });
        });
        
        req.on('error', (err) => {
            resolve({ success: false, error: err.message });
        });
        
        req.setTimeout(3000, () => {
            req.destroy();
            resolve({ success: false, error: 'Timeout' });
        });
    });
}

async function checkConnectivity() {
    const PORT = 3000;
    
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║        📡 Network Connectivity Test for Port 3000         ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');
    
    // Display all network interfaces
    const addresses = getLocalIPAddress();
    
    if (addresses.length === 0) {
        console.log('❌ No network interfaces found!');
        console.log('   Please check your network connection.\n');
        return;
    }
    
    console.log('📋 Available Network Interfaces:\n');
    addresses.forEach(({ name, address }) => {
        console.log(`   ${name.padEnd(30)} ${address}`);
    });
    
    console.log('\n🔍 Testing server connectivity...\n');
    
    // Test localhost
    console.log('Testing localhost (127.0.0.1)...');
    const localhostTest = await testPort('localhost', PORT);
    if (localhostTest.success) {
        console.log(`✅ Localhost: http://localhost:${PORT} (Status: ${localhostTest.status})`);
    } else {
        console.log(`❌ Localhost: ${localhostTest.error}`);
    }
    
    // Test each network interface
    for (const { address } of addresses) {
        console.log(`\nTesting ${address}...`);
        const result = await testPort(address, PORT);
        if (result.success) {
            console.log(`✅ ${address}: http://${address}:${PORT} (Status: ${result.status})`);
            console.log(`   📱 Other devices can use: http://${address}:${PORT}`);
        } else {
            console.log(`❌ ${address}: ${result.error}`);
        }
    }
    
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('\n💡 Tips for connecting from other devices:\n');
    console.log('   1. Make sure the server is running (node app.js)');
    console.log('   2. Both devices must be on the SAME Wi-Fi network');
    console.log('   3. Windows Firewall must allow port 3000');
    console.log('      Run: setup-firewall.bat (as Administrator)');
    console.log('   4. Some antivirus software may block connections');
    console.log('   5. Update Flutter app config.dart with the correct IP\n');
}

checkConnectivity();

"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getWifiIpAddress = getWifiIpAddress;
exports.updateConfigEnv = updateConfigEnv;
const os_1 = __importDefault(require("os"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
/**
 * Resolves the primary active IPv4 address on the host Wi-Fi interface.
 */
function getWifiIpAddress() {
    const interfaces = os_1.default.networkInterfaces();
    // Look for common Wi-Fi interface patterns
    const wifiNames = ['wi-fi', 'wifi', 'wlan', 'wireless'];
    for (const name of Object.keys(interfaces)) {
        const isWifi = wifiNames.some(w => name.toLowerCase().includes(w));
        if (!isWifi)
            continue;
        const nets = interfaces[name] || [];
        for (const net of nets) {
            // Return first IPv4 address that is not a loopback address
            if (net.family === 'IPv4' && !net.internal) {
                return net.address;
            }
        }
    }
    // Fallback to searching any non-internal IPv4 address if Wi-Fi naming wasn't detected
    for (const name of Object.keys(interfaces)) {
        const nets = interfaces[name] || [];
        for (const net of nets) {
            if (net.family === 'IPv4' && !net.internal) {
                return net.address;
            }
        }
    }
    return '127.0.0.1';
}
/**
 * Automatically updates or adds the host IP configuration in the .env file.
 * Only call this in local development — the caller is responsible for checking the environment.
 */
function updateConfigEnv(ip) {
    try {
        const envPath = path_1.default.join(__dirname, '..', '..', '.env');
        if (!fs_1.default.existsSync(envPath)) {
            fs_1.default.writeFileSync(envPath, `PORT=3000\nMONGO_URI=mongodb+srv://Auric:1234@cluster0.ujdtffc.mongodb.net/?retryWrites=true&w=majority\n`);
        }
        let envContent = fs_1.default.readFileSync(envPath, 'utf8');
        if (envContent.includes('HOST_IP=')) {
            envContent = envContent.replace(/HOST_IP=.*/g, `HOST_IP=${ip}`);
        }
        else {
            envContent += `\nHOST_IP=${ip}`;
        }
        fs_1.default.writeFileSync(envPath, envContent, 'utf8');
    }
    catch (err) {
        console.warn(`[Network] Could not update .env file: ${err.message || err}`);
    }
}

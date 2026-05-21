"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const app_1 = __importDefault(require("./app"));
const config_1 = __importDefault(require("./config"));
const db_1 = require("./config/db");
const network_1 = require("./utils/network");
const seed_1 = require("./config/seed");
const PORT = config_1.default.port;
async function bootstrap() {
    // ALWAYS bind to 0.0.0.0 — this works on local dev, Docker containers,
    // Pterodactyl panels, Render, Railway, Heroku, and every other platform.
    // There is ZERO reason to ever bind to a specific interface IP.
    const bindHost = '0.0.0.0';
    // Resolve a display IP for the startup banner (informational only)
    const displayIp = (0, network_1.getWifiIpAddress)();
    console.log(`[Network] Detected network interface IP: ${displayIp}`);
    // Only attempt .env updates in local development (not containers/cloud)
    const isLocalDev = !isContainerOrCloud();
    if (isLocalDev) {
        (0, network_1.updateConfigEnv)(displayIp);
    }
    else {
        console.log(`[Network] Container/cloud environment detected. Skipping .env update.`);
    }
    // Establish Database Connection
    await (0, db_1.connectDatabase)();
    // Seed default admin user
    await (0, seed_1.seedAdminUser)();
    // Start Listening — always on 0.0.0.0
    app_1.default.listen(PORT, bindHost, () => {
        const accessUrl = displayIp !== '127.0.0.1' ? displayIp : 'localhost';
        console.log(`==================================================`);
        console.log(` AxiOS TS Backend Server is LIVE`);
        console.log(` Listening on: ${bindHost}:${PORT}`);
        console.log(` Access URL:   http://${accessUrl}:${PORT}`);
        console.log(` Mode: MONGODB ATLAS INTEGRATED (CLEAN ARCHITECTURE)`);
        console.log(` Storage Dir: ${config_1.default.uploadDir}`);
        console.log(` GET  /api/status`);
        console.log(` GET  /api/download/libil2cpp`);
        console.log(` POST /api/upload`);
        console.log(`==================================================`);
    });
}
/**
 * Detects if we are running inside a container or cloud environment.
 * Checks multiple signals — does NOT rely solely on PORT or NODE_ENV.
 */
function isContainerOrCloud() {
    // Explicit production mode
    if (process.env.NODE_ENV === 'production')
        return true;
    // Common cloud/container env vars
    if (process.env.CONTAINER || process.env.DOCKER || process.env.KUBERNETES_SERVICE_HOST)
        return true;
    // Pterodactyl / game panel detection
    if (process.env.P_SERVER_UUID || process.env.SERVER_MEMORY || process.env.STARTUP)
        return true;
    // Running inside Docker (/.dockerenv exists or /proc/1/cgroup mentions docker)
    try {
        const fs = require('fs');
        if (fs.existsSync('/.dockerenv'))
            return true;
        if (fs.existsSync('/proc/1/cgroup')) {
            const cgroup = fs.readFileSync('/proc/1/cgroup', 'utf8');
            if (cgroup.includes('docker') || cgroup.includes('kubepods') || cgroup.includes('containerd'))
                return true;
        }
    }
    catch (_) {
        // Not on Linux or no access — that's fine
    }
    // Home directory is /home/container (Pterodactyl)
    if (process.env.HOME === '/home/container')
        return true;
    // If the user set HOST_IP explicitly, they know what they're doing
    if (process.env.HOST_IP)
        return false;
    return false;
}
bootstrap().catch((error) => {
    console.error('[Bootstrap] Critical server startup exception:', error);
    process.exit(1);
});

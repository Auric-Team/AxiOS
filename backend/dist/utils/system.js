"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSystemInfo = getSystemInfo;
const os_1 = __importDefault(require("os"));
/**
 * Reads real-time hardware diagnostics and OS metrics.
 */
function getSystemInfo() {
    const totalMemory = os_1.default.totalmem();
    const freeMemory = os_1.default.freemem();
    const memoryUsagePercentage = totalMemory > 0
        ? parseFloat(((1 - freeMemory / totalMemory) * 100).toFixed(2))
        : 0;
    const cpus = os_1.default.cpus() || [];
    const cpuModel = cpus.length > 0 ? cpus[0].model : 'Unknown Hardware';
    // Returns 1, 5, and 15 min load averages. (Windows defaults to [0, 0, 0])
    const loadAverage = os_1.default.loadavg() || [0, 0, 0];
    return {
        platform: os_1.default.platform(),
        release: os_1.default.release(),
        uptime: os_1.default.uptime(),
        totalMemory,
        freeMemory,
        memoryUsagePercentage,
        cpuModel,
        cpuCores: cpus.length,
        loadAverage,
    };
}

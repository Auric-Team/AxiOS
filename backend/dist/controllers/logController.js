"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getLogs = getLogs;
exports.clearLogs = clearLogs;
const Log_1 = __importDefault(require("../models/Log"));
/**
 * Admin-only: Fetch system logs with optional filtering.
 */
async function getLogs(req, res) {
    try {
        const { level, category, limit } = req.query;
        const filter = {};
        if (level)
            filter.level = level;
        if (category)
            filter.category = category;
        const limitVal = parseInt(limit || '100', 10);
        const logs = await Log_1.default.find(filter)
            .sort({ timestamp: -1 })
            .limit(limitVal);
        res.json({ success: true, logs });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to fetch logs.' });
    }
}
/**
 * Admin-only: Clear all logs.
 */
async function clearLogs(req, res) {
    try {
        await Log_1.default.deleteMany({});
        console.log(`[Admin Log] Logs cleared by ${req.user?.username}`);
        res.json({ success: true, message: 'Logs cleared successfully.' });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to clear logs.' });
    }
}

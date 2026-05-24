"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getLogs = getLogs;
exports.clearLogs = clearLogs;
const Log_1 = __importDefault(require("../models/Log"));
/**
 * Admin-only: Fetch system logs with pagination and search filtering.
 */
async function getLogs(req, res) {
    try {
        const { level, category, page, limit, search } = req.query;
        const filter = {};
        if (level && level !== 'ALL') {
            filter.level = level;
        }
        if (category && category !== 'ALL') {
            filter.category = category;
        }
        if (search) {
            const searchStr = search.trim();
            const escapedSearch = searchStr.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const searchRegex = new RegExp(escapedSearch, 'i');
            filter.$or = [
                { message: searchRegex },
                { ip: searchRegex },
                { deviceInfo: searchRegex }
            ];
        }
        const pageVal = parseInt(page || '1', 10);
        const limitVal = parseInt(limit || '50', 10);
        const skipVal = (pageVal - 1) * limitVal;
        const total = await Log_1.default.countDocuments(filter);
        const logs = await Log_1.default.find(filter)
            .sort({ timestamp: -1 })
            .skip(skipVal)
            .limit(limitVal);
        res.json({
            success: true,
            logs,
            pagination: {
                total,
                page: pageVal,
                limit: limitVal,
                pages: Math.ceil(total / limitVal)
            }
        });
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

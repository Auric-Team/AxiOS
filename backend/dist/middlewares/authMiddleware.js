"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
exports.requireAdmin = requireAdmin;
const User_1 = __importDefault(require("../models/User"));
/**
 * Middleware validating bearer tokens and appending user payload to Requests.
 */
async function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Access token required.' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const payload = JSON.parse(Buffer.from(token, 'base64').toString('utf8'));
        if (payload.exp < Date.now()) {
            return res.status(401).json({ error: 'Access token expired.' });
        }
        // Verify user exists in the database
        const user = await User_1.default.findOne({ username: payload.username });
        if (!user) {
            return res.status(401).json({ error: 'User does not exist.' });
        }
        req.user = { username: user.username, role: user.role };
        next();
    }
    catch (error) {
        res.status(401).json({ error: 'Invalid access token.' });
    }
}
/**
 * Middleware restricting access to administrator role only.
 */
function requireAdmin(req, res, next) {
    if (!req.user || req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Access denied. Administrative privilege required.' });
    }
    next();
}

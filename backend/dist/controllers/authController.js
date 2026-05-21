"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = register;
exports.login = login;
exports.verify = verify;
exports.getAllUsers = getAllUsers;
exports.deleteUser = deleteUser;
exports.updateUserRole = updateUserRole;
const User_1 = __importDefault(require("../models/User"));
const crypto_1 = require("../utils/crypto");
const Log_1 = require("../models/Log");
/**
 * Register a new user account.
 */
async function register(req, res) {
    const ip = req.ip || req.socket?.remoteAddress || '127.0.0.1';
    try {
        const { username, password, makeAdmin, deviceFingerprint } = req.body;
        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password are required.' });
        }
        const cleanUsername = username.trim();
        const escapedUsername = cleanUsername.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const exists = await User_1.default.findOne({
            username: { $regex: new RegExp(`^${escapedUsername}$`, 'i') }
        });
        if (exists) {
            await (0, Log_1.dbLog)('warn', 'auth', `Registration failed: username ${cleanUsername} already exists`, ip);
            return res.status(400).json({ error: 'Username is already taken.' });
        }
        const count = await User_1.default.countDocuments();
        const role = (count === 0 || makeAdmin === true) ? 'admin' : 'user';
        let incomingFP = (deviceFingerprint || '').trim();
        if (!incomingFP) {
            incomingFP = 'AXIOS-FP-BACKEND-FALLBACK-' + Buffer.from(cleanUsername).toString('hex').toUpperCase();
        }
        const newUser = new User_1.default({
            username: cleanUsername,
            passwordHash: (0, crypto_1.hashPassword)(password),
            role,
            deviceFingerprint: incomingFP
        });
        await newUser.save();
        await (0, Log_1.dbLog)('info', 'auth', `Registered new user: ${cleanUsername} as role: ${role} (FP: ${incomingFP})`, ip);
        res.json({ success: true, message: 'User registered successfully.', role });
    }
    catch (e) {
        console.error('[Auth] Registration Exception:', e);
        await (0, Log_1.dbLog)('error', 'auth', `Registration exception: ${e.stack || e.message || e}`, ip);
        res.status(500).json({ error: 'Internal Server Error during registration.' });
    }
}
/**
 * Log in a user and return a base64 session token.
 */
async function login(req, res) {
    const ip = req.ip || req.socket?.remoteAddress || '127.0.0.1';
    try {
        const { username, password, deviceFingerprint } = req.body;
        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password are required.' });
        }
        const cleanUsername = username.trim();
        const escapedUsername = cleanUsername.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const user = await User_1.default.findOne({
            username: { $regex: new RegExp(`^${escapedUsername}$`, 'i') }
        });
        if (!user || user.passwordHash !== (0, crypto_1.hashPassword)(password)) {
            await (0, Log_1.dbLog)('warn', 'auth', `Login failed: Invalid credentials for user: ${cleanUsername}`, ip);
            return res.status(401).json({ error: 'Invalid credentials.' });
        }
        // Device Fingerprint Binding for standard users
        let incomingFP = (deviceFingerprint || '').trim();
        if (!incomingFP) {
            incomingFP = 'AXIOS-FP-BACKEND-FALLBACK-' + Buffer.from(cleanUsername).toString('hex').toUpperCase();
        }
        if (user.role === 'user') {
            if (!user.deviceFingerprint) {
                // Bind on first login if it was somehow empty
                user.deviceFingerprint = incomingFP;
                await user.save();
                await (0, Log_1.dbLog)('info', 'auth', `Bound device fingerprint to user ${user.username}: ${incomingFP}`, ip);
            }
            else if (user.deviceFingerprint !== incomingFP) {
                await (0, Log_1.dbLog)('warn', 'auth', `Login rejected: Device fingerprint mismatch for user ${user.username} (expected: ${user.deviceFingerprint}, got: ${incomingFP})`, ip);
                return res.status(403).json({ error: 'This security account is bound to another device.' });
            }
        }
        // Generate token valid for 24 hours
        const payload = {
            username: user.username,
            role: user.role,
            exp: Date.now() + 24 * 60 * 60 * 1000
        };
        const token = Buffer.from(JSON.stringify(payload)).toString('base64');
        await (0, Log_1.dbLog)('info', 'auth', `Successfully logged in: ${user.username} (${user.role})`, ip);
        res.json({ success: true, token, role: user.role });
    }
    catch (e) {
        console.error('[Auth] Login Exception:', e);
        await (0, Log_1.dbLog)('error', 'auth', `Login exception: ${e.stack || e.message || e}`, ip);
        res.status(500).json({ error: 'Internal Server Error during login.' });
    }
}
/**
 * Verify a token (session retrieval).
 */
async function verify(req, res) {
    res.json({ success: true, username: req.user?.username, role: req.user?.role });
}
/**
 * Admin-only: Fetch all users.
 */
async function getAllUsers(req, res) {
    try {
        const users = await User_1.default.find({}, { passwordHash: 0 }).sort({ createdAt: -1 });
        res.json({ success: true, users });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to fetch users.' });
    }
}
/**
 * Admin-only: Delete a user.
 */
async function deleteUser(req, res) {
    try {
        const { userId } = req.params;
        const deleted = await User_1.default.findByIdAndDelete(userId);
        if (!deleted) {
            return res.status(404).json({ error: 'User not found.' });
        }
        await (0, Log_1.dbLog)('info', 'auth', `Deleted user account: ${deleted.username} (Admin: ${req.user?.username})`);
        res.json({ success: true, message: 'User deleted successfully.' });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to delete user.' });
    }
}
/**
 * Admin-only: Update a user's role.
 */
async function updateUserRole(req, res) {
    try {
        const { userId } = req.params;
        const { role } = req.body;
        if (!role || (role !== 'admin' && role !== 'user')) {
            return res.status(400).json({ error: 'Invalid role. Must be admin or user.' });
        }
        const user = await User_1.default.findById(userId);
        if (!user) {
            return res.status(404).json({ error: 'User not found.' });
        }
        user.role = role;
        await user.save();
        await (0, Log_1.dbLog)('info', 'auth', `Updated role for user: ${user.username} to ${role} (Admin: ${req.user?.username})`);
        res.json({ success: true, user: { username: user.username, role: user.role } });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to update user role.' });
    }
}

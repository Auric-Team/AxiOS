"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateKey = validateKey;
exports.generateKeys = generateKeys;
exports.getAllKeys = getAllKeys;
exports.deleteKey = deleteKey;
exports.toggleKeyStatus = toggleKeyStatus;
const crypto_1 = __importDefault(require("crypto"));
const Key_1 = __importDefault(require("../models/Key"));
const Log_1 = require("../models/Log");
/**
 * Validates an access key. If valid, increments the usage count.
 * Used by regular users to download files.
 */
async function validateKey(req, res) {
    const ip = req.ip || req.socket.remoteAddress;
    const deviceInfo = req.headers['x-device-info'] || 'Unknown Device';
    try {
        const { key, username, deviceFingerprint } = req.body;
        if (!key) {
            return res.status(400).json({ error: 'Access key is required.' });
        }
        const keyDoc = await Key_1.default.findOne({ key: key.trim() });
        if (!keyDoc) {
            await (0, Log_1.dbLog)('warn', 'key', `Key validation failed: Key not found: ${key}`, ip, deviceInfo);
            return res.status(404).json({ error: 'Invalid access key. Key does not exist.' });
        }
        if (!keyDoc.isActive) {
            await (0, Log_1.dbLog)('warn', 'key', `Key validation failed: Key is deactivated: ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is deactivated.' });
        }
        // Expiry Check
        if (keyDoc.expiresAt && keyDoc.expiresAt < new Date()) {
            await (0, Log_1.dbLog)('warn', 'key', `Key validation failed: Key has expired: ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is outdated/expired. Please contact an administrator.' });
        }
        let incomingFP = (deviceFingerprint || '').trim();
        if (!incomingFP) {
            const salt = username ? username.trim() : key.trim();
            incomingFP = 'AXIOS-FP-BACKEND-FALLBACK-' + Buffer.from(salt).toString('hex').toUpperCase();
        }
        // Device Fingerprint Binding for the key
        if (!keyDoc.deviceFingerprint) {
            keyDoc.deviceFingerprint = incomingFP;
            await (0, Log_1.dbLog)('info', 'key', `Access key ${key} bound to device fingerprint: ${incomingFP}`, ip, deviceInfo);
        }
        else if (keyDoc.deviceFingerprint !== incomingFP) {
            await (0, Log_1.dbLog)('warn', 'key', `Key validation failed: Key bound to device ${keyDoc.deviceFingerprint}, attempted by device ${incomingFP}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is bound to another security device.' });
        }
        // Ownership Check
        const activeUser = (username || '').trim();
        if (keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() !== activeUser.toLowerCase()) {
            await (0, Log_1.dbLog)('warn', 'key', `Key validation failed: Key belongs to ${keyDoc.assignedTo}, attempted by ${activeUser}: ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is assigned to another security account.' });
        }
        // Limit Check
        const isOwner = keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() === activeUser.toLowerCase();
        if (!isOwner && keyDoc.usesCount >= keyDoc.maxUses) {
            await (0, Log_1.dbLog)('warn', 'key', `Key validation failed: Key exceeded max uses (${keyDoc.maxUses}): ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key usage limit exceeded.' });
        }
        // Bind on first use if unassigned
        if (!keyDoc.assignedTo && activeUser) {
            keyDoc.assignedTo = activeUser;
            await (0, Log_1.dbLog)('info', 'key', `Access key ${key} bound to user: ${activeUser}`, ip, deviceInfo);
        }
        // Increment usage count only if they are not already the owner (first time binding/use)
        if (!isOwner) {
            keyDoc.usesCount += 1;
        }
        await keyDoc.save();
        await (0, Log_1.dbLog)('info', 'key', `Key validated successfully: ${key} (User: ${keyDoc.assignedTo || 'Anonymous'}) (Usage: ${keyDoc.usesCount}/${keyDoc.maxUses})`, ip, deviceInfo);
        res.json({
            success: true,
            message: 'Access key activated successfully.',
            targetGame: keyDoc.targetGame
        });
    }
    catch (e) {
        console.error('[Key] Validation Exception:', e);
        await (0, Log_1.dbLog)('error', 'key', `Key validation exception: ${e.message || e}`, ip, deviceInfo);
        res.status(500).json({ error: 'Internal Server Error during key validation.' });
    }
}
/**
 * Admin-only: Generate new keys.
 */
async function generateKeys(req, res) {
    try {
        const { prefix, count, maxUses, expiresInHours, targetGame, assignedTo } = req.body;
        const keyCount = parseInt(count || '1', 10);
        const uses = parseInt(maxUses || '1', 10);
        const target = targetGame || 'com.herogame.gplay.lastdayrulessurvival';
        const creator = req.user?.username || 'Admin';
        const assignedUser = (assignedTo || '').trim();
        const expiresAt = expiresInHours && parseInt(expiresInHours, 10) > 0
            ? new Date(Date.now() + parseInt(expiresInHours, 10) * 60 * 60 * 1000)
            : undefined;
        const generatedKeys = [];
        for (let i = 0; i < keyCount; i++) {
            const randomString = crypto_1.default.randomBytes(8).toString('hex').toUpperCase();
            const keyValue = prefix ? `${prefix}-${randomString}` : `AXIOS-${randomString}`;
            const keyDoc = new Key_1.default({
                key: keyValue,
                maxUses: uses,
                targetGame: target,
                assignedTo: assignedUser,
                createdBy: creator,
                expiresAt
            });
            await keyDoc.save();
            generatedKeys.push(keyDoc);
        }
        await (0, Log_1.dbLog)('info', 'key', `Generated ${keyCount} new access keys (Assigned: ${assignedUser || 'None'}, Creator: ${creator})`);
        res.json({ success: true, keys: generatedKeys });
    }
    catch (e) {
        console.error('[Key] Generation Exception:', e);
        res.status(500).json({ error: 'Failed to generate access keys.' });
    }
}
/**
 * Admin-only: Fetch all keys.
 */
async function getAllKeys(req, res) {
    try {
        const keys = await Key_1.default.find().sort({ createdAt: -1 });
        res.json({ success: true, keys });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to fetch access keys.' });
    }
}
/**
 * Admin-only: Delete a key.
 */
async function deleteKey(req, res) {
    try {
        const { keyId } = req.params;
        const deleted = await Key_1.default.findByIdAndDelete(keyId);
        if (!deleted) {
            return res.status(404).json({ error: 'Access key not found.' });
        }
        await (0, Log_1.dbLog)('info', 'key', `Deleted access key: ${deleted.key} (Admin: ${req.user?.username})`);
        res.json({ success: true, message: 'Key deleted successfully.' });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to delete access key.' });
    }
}
/**
 * Admin-only: Toggle key active status.
 */
async function toggleKeyStatus(req, res) {
    try {
        const { keyId } = req.params;
        const keyDoc = await Key_1.default.findById(keyId);
        if (!keyDoc) {
            return res.status(404).json({ error: 'Access key not found.' });
        }
        keyDoc.isActive = !keyDoc.isActive;
        await keyDoc.save();
        await (0, Log_1.dbLog)('info', 'key', `Toggled access key state: ${keyDoc.key} (Active: ${keyDoc.isActive}) (Admin: ${req.user?.username})`);
        res.json({ success: true, key: keyDoc });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to toggle access key status.' });
    }
}

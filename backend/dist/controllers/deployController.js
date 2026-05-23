"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getStatus = getStatus;
exports.downloadBinary = downloadBinary;
exports.uploadBinary = uploadBinary;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const mongoose_1 = __importDefault(require("mongoose"));
const config_1 = __importDefault(require("../config"));
const Key_1 = __importDefault(require("../models/Key"));
const Log_1 = require("../models/Log");
const system_1 = require("../utils/system");
const defaultLibil2cppPath = path_1.default.join(config_1.default.uploadDir, 'libil2cpp.so');
/**
 * Returns system backend details, database connections state, and binary metadata.
 */
function getStatus(req, res) {
    const exists = fs_1.default.existsSync(defaultLibil2cppPath);
    res.json({
        status: 'online',
        message: 'AxiOS Deployment Backend is ready.',
        config: {
            uploadDir: config_1.default.uploadDir,
            mockBinaryEnabled: config_1.default.mockBinary,
            logLevel: config_1.default.logLevel,
            dbStatus: mongoose_1.default.connection.readyState === 1 ? 'connected' : 'disconnected'
        },
        system: (0, system_1.getSystemInfo)(),
        binaryExists: exists,
        binarySize: exists ? fs_1.default.statSync(defaultLibil2cppPath).size : 0,
        timestamp: new Date().toISOString()
    });
}
/**
 * Streams the libil2cpp.so binary file to the requesting client.
 * Requires validation of key, username, and deviceFingerprint.
 */
async function downloadBinary(req, res) {
    const ip = req.ip || req.socket?.remoteAddress || '127.0.0.1';
    const deviceInfo = req.headers['x-device-info'] || 'Unknown Device';
    try {
        const { key, username, deviceFingerprint } = req.query;
        if (!key) {
            await (0, Log_1.dbLog)('warn', 'download', 'Download rejected: License key parameter missing.', ip, deviceInfo);
            return res.status(400).json({ error: 'License key is required to stream secure payload.' });
        }
        const keyDoc = await Key_1.default.findOne({ key: key.trim() });
        if (!keyDoc) {
            await (0, Log_1.dbLog)('warn', 'download', `Download rejected: Key not found: ${key}`, ip, deviceInfo);
            return res.status(404).json({ error: 'Invalid access key. Key does not exist.' });
        }
        if (!keyDoc.isActive) {
            await (0, Log_1.dbLog)('warn', 'download', `Download rejected: Key is deactivated: ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is deactivated.' });
        }
        // Expiry Check
        if (keyDoc.expiresAt && keyDoc.expiresAt < new Date()) {
            await (0, Log_1.dbLog)('warn', 'download', `Download rejected: Key has expired: ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is outdated/expired. Please contact an administrator.' });
        }
        // Device Fingerprint Binding for the key
        let incomingFP = (deviceFingerprint || '').trim();
        if (!incomingFP) {
            const salt = username ? username.trim() : key.trim();
            incomingFP = 'AXIOS-FP-BACKEND-FALLBACK-' + Buffer.from(salt).toString('hex').toUpperCase();
        }
        if (!keyDoc.deviceFingerprint) {
            keyDoc.deviceFingerprint = incomingFP;
            await keyDoc.save();
            await (0, Log_1.dbLog)('info', 'download', `Access key ${key} bound to device fingerprint during download: ${incomingFP}`, ip, deviceInfo);
        }
        else if (keyDoc.deviceFingerprint !== incomingFP) {
            await (0, Log_1.dbLog)('warn', 'download', `Download rejected: Key bound to device ${keyDoc.deviceFingerprint}, attempted by device ${incomingFP}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is bound to another security device.' });
        }
        // Ownership Check
        const activeUser = (username || '').trim();
        if (keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() !== activeUser.toLowerCase()) {
            await (0, Log_1.dbLog)('warn', 'download', `Download rejected: Key belongs to ${keyDoc.assignedTo}, attempted by ${activeUser}: ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key is assigned to another security account.' });
        }
        // Limit Check
        const isOwner = keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() === activeUser.toLowerCase();
        if (!isOwner && keyDoc.usesCount >= keyDoc.maxUses) {
            await (0, Log_1.dbLog)('warn', 'download', `Download rejected: Key exceeded max uses (${keyDoc.maxUses}): ${key}`, ip, deviceInfo);
            return res.status(403).json({ error: 'Access key usage limit exceeded.' });
        }
        if (!fs_1.default.existsSync(defaultLibil2cppPath)) {
            await (0, Log_1.dbLog)('error', 'download', `Download failed: binary file not found on disk: ${defaultLibil2cppPath}`, ip, deviceInfo);
            return res.status(404).json({ error: 'libil2cpp.so binary not found on server.' });
        }
        if (config_1.default.logLevel === 'debug' || config_1.default.logLevel === 'info') {
            console.log(`[Download] Streaming secure libil2cpp.so for key ${keyDoc.key} to client IP: ${ip}`);
        }
        // Log the successful download
        await (0, Log_1.dbLog)('info', 'download', `Streaming libil2cpp.so payload for key: ${keyDoc.key} (User: ${keyDoc.assignedTo || 'Anonymous'})`, ip, deviceInfo);
        const stats = fs_1.default.statSync(defaultLibil2cppPath);
        res.setHeader('Content-Length', stats.size.toString());
        res.setHeader('Content-Disposition', 'attachment; filename=libil2cpp.so');
        res.setHeader('Content-Type', 'application/octet-stream');
        return res.sendFile(path_1.default.resolve(defaultLibil2cppPath));
    }
    catch (err) {
        console.error('[Download] Exception:', err);
        return res.status(500).json({ error: `Internal Server Error during download: ${err.message || err}` });
    }
}
/**
 * Endpoint saving uploaded files to target uploads folders.
 * Automatically clears out the old binary if one exists.
 */
async function uploadBinary(req, res) {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded.' });
    }
    const fileDetails = req.file;
    try {
        // If the diskStorage callback saved it as libil2cpp.so, it will have replaced it.
        // However, to guarantee the old file is deleted and clean up space correctly,
        // we double-check the default path.
        if (fs_1.default.existsSync(defaultLibil2cppPath) && fileDetails.path !== defaultLibil2cppPath) {
            fs_1.default.unlinkSync(defaultLibil2cppPath);
        }
        // Move the uploaded file to the default location if multer saved it differently
        if (fileDetails.path !== defaultLibil2cppPath) {
            fs_1.default.renameSync(fileDetails.path, defaultLibil2cppPath);
        }
        const ip = req.ip || req.socket.remoteAddress;
        const adminUser = req.user?.username || 'admin';
        // Import dynamically to avoid circular references if any
        const { dbLog } = require('../models/Log');
        await dbLog('info', 'binary', `Admin ${adminUser} uploaded and replaced libil2cpp.so file (${fileDetails.size} bytes)`, ip);
        if (config_1.default.logLevel !== 'error') {
            console.log(`[Upload] Successfully uploaded and replaced libil2cpp.so (${fileDetails.size} bytes)`);
        }
        res.json({
            success: true,
            message: 'libil2cpp.so uploaded and updated successfully. Old file replaced.',
            size: fileDetails.size
        });
    }
    catch (err) {
        console.error('[Upload] Error replacing binary:', err);
        res.status(500).json({ error: `Failed to update binary: ${err.message || err}` });
    }
}

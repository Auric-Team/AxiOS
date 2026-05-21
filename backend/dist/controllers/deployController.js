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
        binaryExists: exists,
        binarySize: exists ? fs_1.default.statSync(defaultLibil2cppPath).size : 0,
        timestamp: new Date().toISOString()
    });
}
/**
 * Streams the libil2cpp.so binary file to the requesting client.
 */
function downloadBinary(req, res) {
    if (!fs_1.default.existsSync(defaultLibil2cppPath)) {
        if (config_1.default.logLevel !== 'error') {
            console.warn(`[Warning] Download requested but binary not found: ${defaultLibil2cppPath}`);
        }
        return res.status(404).json({ error: 'libil2cpp.so binary not found on server.' });
    }
    if (config_1.default.logLevel === 'debug' || config_1.default.logLevel === 'info') {
        console.log(`[Download] Streaming libil2cpp.so to client IP: ${req.ip}`);
    }
    res.setHeader('Content-Disposition', 'attachment; filename=libil2cpp.so');
    res.setHeader('Content-Type', 'application/octet-stream');
    const fileStream = fs_1.default.createReadStream(defaultLibil2cppPath);
    fileStream.pipe(res);
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

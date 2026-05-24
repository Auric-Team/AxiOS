import { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import mongoose from 'mongoose';
import config from '../config';
import Key from '../models/Key';
import { dbLog } from '../models/Log';

import { getSystemInfo } from '../utils/system';

const defaultLibil2cppPath = path.join(config.uploadDir, 'libil2cpp.so');

/**
 * Returns system backend details, database connections state, and binary metadata.
 */
export function getStatus(req: Request, res: Response) {
  const exists = fs.existsSync(defaultLibil2cppPath);
  
  // Scan payloads folder for custom profiles
  const payloadProfiles: string[] = [];
  const payloadsDir = path.join(config.uploadDir, 'payloads');
  if (fs.existsSync(payloadsDir)) {
    try {
      const folders = fs.readdirSync(payloadsDir);
      for (const folder of folders) {
        const p = path.join(payloadsDir, folder, 'libil2cpp.so');
        if (fs.existsSync(p)) {
          payloadProfiles.push(folder);
        }
      }
    } catch (_) {}
  }

  res.json({
    status: 'online',
    message: 'AxiOS Deployment Backend is ready.',
    config: {
      uploadDir: config.uploadDir,
      mockBinaryEnabled: config.mockBinary,
      logLevel: config.logLevel,
      dbStatus: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
    },
    system: getSystemInfo(),
    binaryExists: exists,
    binarySize: exists ? fs.statSync(defaultLibil2cppPath).size : 0,
    payloadProfiles, // Array of package names that have custom binaries
    timestamp: new Date().toISOString()
  });
}

/**
 * Streams the libil2cpp.so binary file to the requesting client.
 * Requires validation of key, username, and deviceFingerprint.
 */
export async function downloadBinary(req: Request, res: Response) {
  const ip = req.ip || req.socket?.remoteAddress || '127.0.0.1';
  const deviceInfo = req.headers['x-device-info'] as string || 'Unknown Device';

  try {
    const { key, username, deviceFingerprint } = req.query;

    if (!key) {
      await dbLog('warn', 'download', 'Download rejected: License key parameter missing.', ip, deviceInfo);
      return res.status(400).json({ error: 'License key is required to stream secure payload.' });
    }

    const keyDoc = await Key.findOne({ key: (key as string).trim() });
    if (!keyDoc) {
      await dbLog('warn', 'download', `Download rejected: Key not found: ${key}`, ip, deviceInfo);
      return res.status(404).json({ error: 'Invalid access key. Key does not exist.' });
    }

    if (!keyDoc.isActive) {
      await dbLog('warn', 'download', `Download rejected: Key is deactivated: ${key}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key is deactivated.' });
    }

    // Expiry Check
    if (keyDoc.expiresAt && keyDoc.expiresAt < new Date()) {
      await dbLog('warn', 'download', `Download rejected: Key has expired: ${key}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key is outdated/expired. Please contact an administrator.' });
    }

    // Device Fingerprint Binding for the key
    let incomingFP = ((deviceFingerprint as string) || '').trim();
    if (!incomingFP) {
      const salt = username ? (username as string).trim() : (key as string).trim();
      incomingFP = 'AXIOS-FP-BACKEND-FALLBACK-' + Buffer.from(salt).toString('hex').toUpperCase();
    }

    if (!keyDoc.deviceFingerprint) {
      keyDoc.deviceFingerprint = incomingFP;
      await keyDoc.save();
      await dbLog('info', 'download', `Access key ${key} bound to device fingerprint during download: ${incomingFP}`, ip, deviceInfo);
    } else if (keyDoc.deviceFingerprint !== incomingFP) {
      await dbLog('warn', 'download', `Download rejected: Key bound to device ${keyDoc.deviceFingerprint}, attempted by device ${incomingFP}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key is bound to another security device.' });
    }

    // Ownership Check
    const activeUser = ((username as string) || '').trim();
    if (keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() !== activeUser.toLowerCase()) {
      await dbLog('warn', 'download', `Download rejected: Key belongs to ${keyDoc.assignedTo}, attempted by ${activeUser}: ${key}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key is assigned to another security account.' });
    }

    // Limit Check
    const isOwner = keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() === activeUser.toLowerCase();
    if (!isOwner && keyDoc.usesCount >= keyDoc.maxUses) {
      await dbLog('warn', 'download', `Download rejected: Key exceeded max uses (${keyDoc.maxUses}): ${key}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key usage limit exceeded.' });
    }

    // Resolve dynamic payload binary location matching game target package
    let binaryPath = defaultLibil2cppPath;
    let isCustomPayload = false;

    if (keyDoc.targetGame) {
      const sanitizedGame = keyDoc.targetGame.replace(/[^a-zA-Z0-9._-]/g, '');
      const customPath = path.join(config.uploadDir, 'payloads', sanitizedGame, 'libil2cpp.so');
      if (fs.existsSync(customPath)) {
        binaryPath = customPath;
        isCustomPayload = true;
      }
    }

    if (!fs.existsSync(binaryPath)) {
      await dbLog('error', 'download', `Download failed: binary file not found on disk: ${binaryPath}`, ip, deviceInfo);
      return res.status(404).json({ error: 'Payload binary not found on server.' });
    }

    if (config.logLevel === 'debug' || config.logLevel === 'info') {
      console.log(`[Download] Streaming secure libil2cpp.so (custom: ${isCustomPayload}) for key ${keyDoc.key} to client IP: ${ip}`);
    }

    // Log the successful download
    await dbLog('info', 'download', `Streaming libil2cpp.so payload (${isCustomPayload ? 'Custom Profile: ' + keyDoc.targetGame : 'Global Default'}) for key: ${keyDoc.key} (User: ${keyDoc.assignedTo || 'Anonymous'})`, ip, deviceInfo);

    const stats = fs.statSync(binaryPath);
    res.setHeader('Content-Length', stats.size.toString());
    res.setHeader('Content-Disposition', 'attachment; filename=libil2cpp.so');
    res.setHeader('Content-Type', 'application/octet-stream');

    return res.sendFile(path.resolve(binaryPath));
  } catch (err: any) {
    console.error('[Download] Exception:', err);
    return res.status(500).json({ error: `Internal Server Error during download: ${err.message || err}` });
  }
}

/**
 * Endpoint saving uploaded files to target uploads folders.
 * Automatically handles target profiles when ?targetGame query parameter is provided.
 */
export async function uploadBinary(req: Request, res: Response) {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded.' });
  }

  const fileDetails = req.file;
  const targetGame = (req.query.targetGame as string || '').trim();

  try {
    const ip = req.ip || req.socket?.remoteAddress || '127.0.0.1';
    const adminUser = (req as any).user?.username || 'admin';
    
    // Import dynamically to avoid circular references
    const { dbLog } = require('../models/Log');

    if (targetGame) {
      await dbLog('info', 'binary', `Admin ${adminUser} uploaded custom libil2cpp.so for profile ${targetGame} (${fileDetails.size} bytes)`, ip);
      if (config.logLevel !== 'error') {
        console.log(`[Upload] Successfully uploaded custom payload for ${targetGame} (${fileDetails.size} bytes)`);
      }
      res.json({
        success: true,
        message: `libil2cpp.so uploaded successfully for game profile: ${targetGame}`,
        size: fileDetails.size,
        targetGame
      });
    } else {
      await dbLog('info', 'binary', `Admin ${adminUser} uploaded and replaced default global libil2cpp.so file (${fileDetails.size} bytes)`, ip);
      if (config.logLevel !== 'error') {
        console.log(`[Upload] Successfully uploaded default libil2cpp.so (${fileDetails.size} bytes)`);
      }
      res.json({
        success: true,
        message: 'Default global libil2cpp.so uploaded and updated successfully.',
        size: fileDetails.size
      });
    }
  } catch (err: any) {
    console.error('[Upload] Error processing binary upload:', err);
    res.status(500).json({ error: `Failed to update binary: ${err.message || err}` });
  }
}

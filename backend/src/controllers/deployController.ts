import { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import mongoose from 'mongoose';
import config from '../config';

const defaultLibil2cppPath = path.join(config.uploadDir, 'libil2cpp.so');

/**
 * Returns system backend details, database connections state, and binary metadata.
 */
export function getStatus(req: Request, res: Response) {
  const exists = fs.existsSync(defaultLibil2cppPath);
  res.json({
    status: 'online',
    message: 'AxiOS Deployment Backend is ready.',
    config: {
      uploadDir: config.uploadDir,
      mockBinaryEnabled: config.mockBinary,
      logLevel: config.logLevel,
      dbStatus: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
    },
    binaryExists: exists,
    binarySize: exists ? fs.statSync(defaultLibil2cppPath).size : 0,
    timestamp: new Date().toISOString()
  });
}

/**
 * Streams the libil2cpp.so binary file to the requesting client.
 */
export function downloadBinary(req: Request, res: Response) {
  if (!fs.existsSync(defaultLibil2cppPath)) {
    if (config.logLevel !== 'error') {
      console.warn(`[Warning] Download requested but binary not found: ${defaultLibil2cppPath}`);
    }
    return res.status(404).json({ error: 'libil2cpp.so binary not found on server.' });
  }

  if (config.logLevel === 'debug' || config.logLevel === 'info') {
    console.log(`[Download] Streaming libil2cpp.so to client IP: ${req.ip}`);
  }

  res.setHeader('Content-Disposition', 'attachment; filename=libil2cpp.so');
  res.setHeader('Content-Type', 'application/octet-stream');

  const fileStream = fs.createReadStream(defaultLibil2cppPath);
  fileStream.pipe(res);
}

/**
 * Endpoint saving uploaded files to target uploads folders.
 * Automatically clears out the old binary if one exists.
 */
export async function uploadBinary(req: Request, res: Response) {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded.' });
  }

  const fileDetails = req.file;

  try {
    // If the diskStorage callback saved it as libil2cpp.so, it will have replaced it.
    // However, to guarantee the old file is deleted and clean up space correctly,
    // we double-check the default path.
    if (fs.existsSync(defaultLibil2cppPath) && fileDetails.path !== defaultLibil2cppPath) {
      fs.unlinkSync(defaultLibil2cppPath);
    }

    // Move the uploaded file to the default location if multer saved it differently
    if (fileDetails.path !== defaultLibil2cppPath) {
      fs.renameSync(fileDetails.path, defaultLibil2cppPath);
    }

    const ip = req.ip || req.socket.remoteAddress;
    const adminUser = (req as any).user?.username || 'admin';
    
    // Import dynamically to avoid circular references if any
    const { dbLog } = require('../models/Log');
    await dbLog('info', 'binary', `Admin ${adminUser} uploaded and replaced libil2cpp.so file (${fileDetails.size} bytes)`, ip);

    if (config.logLevel !== 'error') {
      console.log(`[Upload] Successfully uploaded and replaced libil2cpp.so (${fileDetails.size} bytes)`);
    }

    res.json({
      success: true,
      message: 'libil2cpp.so uploaded and updated successfully. Old file replaced.',
      size: fileDetails.size
    });
  } catch (err: any) {
    console.error('[Upload] Error replacing binary:', err);
    res.status(500).json({ error: `Failed to update binary: ${err.message || err}` });
  }
}

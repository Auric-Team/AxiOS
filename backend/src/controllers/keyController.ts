import { Request, Response } from 'express';
import crypto from 'crypto';
import Key from '../models/Key';
import { dbLog } from '../models/Log';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';

/**
 * Validates an access key. If valid, increments the usage count.
 * Used by regular users to download files.
 */
export async function validateKey(req: Request, res: Response) {
  const ip = req.ip || req.socket.remoteAddress;
  const deviceInfo = req.headers['x-device-info'] as string || 'Unknown Device';
  
  try {
    const { key, username, deviceFingerprint } = req.body;
    if (!key) {
      return res.status(400).json({ error: 'Access key is required.' });
    }

    const keyDoc = await Key.findOne({ key: key.trim() });
    if (!keyDoc) {
      await dbLog('warn', 'key', `Key validation failed: Key not found: ${key}`, ip, deviceInfo);
      return res.status(404).json({ error: 'Invalid access key. Key does not exist.' });
    }

    if (!keyDoc.isActive) {
      await dbLog('warn', 'key', `Key validation failed: Key is deactivated: ${key}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key is deactivated.' });
    }

    // Expiry Check
    if (keyDoc.expiresAt && keyDoc.expiresAt < new Date()) {
      await dbLog('warn', 'key', `Key validation failed: Key has expired: ${key}`, ip, deviceInfo);
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
      await dbLog('info', 'key', `Access key ${key} bound to device fingerprint: ${incomingFP}`, ip, deviceInfo);
    } else if (keyDoc.deviceFingerprint !== incomingFP) {
      await dbLog('warn', 'key', `Key validation failed: Key bound to device ${keyDoc.deviceFingerprint}, attempted by device ${incomingFP}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key is bound to another security device.' });
    }

    // Ownership Check
    const activeUser = (username || '').trim();
    if (keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() !== activeUser.toLowerCase()) {
      await dbLog('warn', 'key', `Key validation failed: Key belongs to ${keyDoc.assignedTo}, attempted by ${activeUser}: ${key}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key is assigned to another security account.' });
    }

    // Limit Check
    const isOwner = keyDoc.assignedTo && keyDoc.assignedTo.toLowerCase() === activeUser.toLowerCase();
    if (!isOwner && keyDoc.usesCount >= keyDoc.maxUses) {
      await dbLog('warn', 'key', `Key validation failed: Key exceeded max uses (${keyDoc.maxUses}): ${key}`, ip, deviceInfo);
      return res.status(403).json({ error: 'Access key usage limit exceeded.' });
    }

    // Bind on first use if unassigned
    if (!keyDoc.assignedTo && activeUser) {
      keyDoc.assignedTo = activeUser;
      await dbLog('info', 'key', `Access key ${key} bound to user: ${activeUser}`, ip, deviceInfo);
    }

    // Increment usage count only if they are not already the owner (first time binding/use)
    if (!isOwner) {
      keyDoc.usesCount += 1;
    }
    await keyDoc.save();

    await dbLog('info', 'key', `Key validated successfully: ${key} (User: ${keyDoc.assignedTo || 'Anonymous'}) (Usage: ${keyDoc.usesCount}/${keyDoc.maxUses})`, ip, deviceInfo);
    
    res.json({
      success: true,
      message: 'Access key activated successfully.',
      targetGame: keyDoc.targetGame
    });
  } catch (e: any) {
    console.error('[Key] Validation Exception:', e);
    await dbLog('error', 'key', `Key validation exception: ${e.message || e}`, ip, deviceInfo);
    res.status(500).json({ error: 'Internal Server Error during key validation.' });
  }
}

/**
 * Admin-only: Generate new keys.
 */
export async function generateKeys(req: AuthenticatedRequest, res: Response) {
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
      const randomString = crypto.randomBytes(8).toString('hex').toUpperCase();
      const keyValue = prefix ? `${prefix}-${randomString}` : `AXIOS-${randomString}`;

      const keyDoc = new Key({
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

    await dbLog('info', 'key', `Generated ${keyCount} new access keys (Assigned: ${assignedUser || 'None'}, Creator: ${creator})`);
    res.json({ success: true, keys: generatedKeys });
  } catch (e: any) {
    console.error('[Key] Generation Exception:', e);
    res.status(500).json({ error: 'Failed to generate access keys.' });
  }
}

/**
 * Admin-only: Fetch all keys.
 */
export async function getAllKeys(req: AuthenticatedRequest, res: Response) {
  try {
    const keys = await Key.find().sort({ createdAt: -1 });
    res.json({ success: true, keys });
  } catch (e: any) {
    res.status(500).json({ error: 'Failed to fetch access keys.' });
  }
}

/**
 * Admin-only: Delete a key.
 */
export async function deleteKey(req: AuthenticatedRequest, res: Response) {
  try {
    const { keyId } = req.params;
    const deleted = await Key.findByIdAndDelete(keyId);
    if (!deleted) {
      return res.status(404).json({ error: 'Access key not found.' });
    }

    await dbLog('info', 'key', `Deleted access key: ${deleted.key} (Admin: ${req.user?.username})`);
    res.json({ success: true, message: 'Key deleted successfully.' });
  } catch (e: any) {
    res.status(500).json({ error: 'Failed to delete access key.' });
  }
}

/**
 * Admin-only: Toggle key active status.
 */
export async function toggleKeyStatus(req: AuthenticatedRequest, res: Response) {
  try {
    const { keyId } = req.params;
    const keyDoc = await Key.findById(keyId);
    if (!keyDoc) {
      return res.status(404).json({ error: 'Access key not found.' });
    }

    keyDoc.isActive = !keyDoc.isActive;
    await keyDoc.save();

    await dbLog('info', 'key', `Toggled access key state: ${keyDoc.key} (Active: ${keyDoc.isActive}) (Admin: ${req.user?.username})`);
    res.json({ success: true, key: keyDoc });
  } catch (e: any) {
    res.status(500).json({ error: 'Failed to toggle access key status.' });
  }
}

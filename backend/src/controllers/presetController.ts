import { Request, Response } from 'express';
import Preset from '../models/Preset';
import { dbLog } from '../models/Log';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';

/**
 * Fetch all available game presets.
 */
export async function getPresets(req: Request, res: Response) {
  try {
    const presets = await Preset.find().sort({ name: 1 });
    res.json({ success: true, presets });
  } catch (e: any) {
    res.status(500).json({ error: 'Failed to fetch game presets.' });
  }
}

/**
 * Admin-only: Create a new game preset.
 */
export async function createPreset(req: AuthenticatedRequest, res: Response) {
  const ip = req.ip || req.socket.remoteAddress;
  try {
    const { package: pkg, name } = req.body;
    if (!pkg || !name) {
      return res.status(400).json({ error: 'Package ID and Game Name are required.' });
    }

    const cleanPkg = pkg.trim();
    const cleanName = name.trim();

    const exists = await Preset.findOne({ package: cleanPkg });
    if (exists) {
      return res.status(400).json({ error: `Preset already exists for package ID: ${cleanPkg}` });
    }

    const newPreset = new Preset({
      package: cleanPkg,
      name: cleanName
    });

    await newPreset.save();
    await dbLog('info', 'system', `Admin ${req.user?.username} added target preset: ${cleanName} (${cleanPkg})`, ip);

    res.json({ success: true, preset: newPreset });
  } catch (e: any) {
    console.error('[Preset] Creation Error:', e);
    res.status(500).json({ error: 'Failed to create game preset.' });
  }
}

/**
 * Admin-only: Delete a game preset.
 */
export async function deletePreset(req: AuthenticatedRequest, res: Response) {
  const ip = req.ip || req.socket.remoteAddress;
  try {
    const { packageId } = req.params;
    const deleted = await Preset.findOneAndDelete({ package: packageId });
    if (!deleted) {
      return res.status(404).json({ error: 'Preset not found.' });
    }

    await dbLog('info', 'system', `Admin ${req.user?.username} deleted target preset: ${deleted.name} (${deleted.package})`, ip);
    res.json({ success: true, message: 'Game preset deleted successfully.' });
  } catch (e: any) {
    res.status(500).json({ error: 'Failed to delete game preset.' });
  }
}

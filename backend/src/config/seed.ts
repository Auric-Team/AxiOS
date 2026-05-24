import User from '../models/User';
import Preset from '../models/Preset';
import { hashPassword } from '../utils/crypto';
import { dbLog } from '../models/Log';

/**
 * Seeds default administrator credentials and game presets if the collections are empty.
 */
export async function seedAdminUser(): Promise<void> {
  try {
    // 1. Seed Default Administrator
    const adminCount = await User.countDocuments({ role: 'admin' });
    if (adminCount === 0) {
      const defaultAdmin = new User({
        username: 'admin',
        passwordHash: hashPassword('admin123'),
        role: 'admin'
      });
      await defaultAdmin.save();
      await dbLog('info', 'system', 'Database initialized. Created default administrator: admin / admin123');
    }

    // 2. Seed Default Target Preset
    const presetCount = await Preset.countDocuments();
    if (presetCount === 0) {
      const defaultPreset = new Preset({
        name: 'Last Island of Survival',
        package: 'com.herogame.gplay.lastdayrulessurvival'
      });
      await defaultPreset.save();
      await dbLog('info', 'system', 'Database initialized. Created default target preset: Last Island of Survival (com.herogame.gplay.lastdayrulessurvival)');
    }
  } catch (error) {
    console.error('[Seed Error] Failed to seed default system properties:', error);
  }
}

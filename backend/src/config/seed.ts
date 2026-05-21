import User from '../models/User';
import { hashPassword } from '../utils/crypto';
import { dbLog } from '../models/Log';

/**
 * Seeds a default administrator account if the user collection is empty.
 */
export async function seedAdminUser(): Promise<void> {
  try {
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
  } catch (error) {
    console.error('[Seed Error] Failed to seed default admin:', error);
  }
}

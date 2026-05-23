import { Router } from 'express';
import { 
  validateKey, 
  generateKeys, 
  getAllKeys, 
  deleteKey, 
  toggleKeyStatus,
  deactivateAllKeys,
  pruneKeys,
  resetFingerprint
} from '../controllers/keyController';
import { requireAuth, requireAdmin } from '../middlewares/authMiddleware';

const router = Router();

// Public key activation endpoint (used by regular app clients)
router.post('/verify', validateKey);

// Admin-only key management
router.post('/generate', requireAuth, requireAdmin, generateKeys);
router.get('/', requireAuth, requireAdmin, getAllKeys);

// Bulk actions (must precede parameterized routes)
router.patch('/deactivate-all', requireAuth, requireAdmin, deactivateAllKeys);
router.delete('/prune-inactive', requireAuth, requireAdmin, pruneKeys);

// Parameterized routes
router.delete('/:keyId', requireAuth, requireAdmin, deleteKey);
router.patch('/:keyId/status', requireAuth, requireAdmin, toggleKeyStatus);
router.patch('/:keyId/reset-fingerprint', requireAuth, requireAdmin, resetFingerprint);

export default router;


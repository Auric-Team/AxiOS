import { Router } from 'express';
import { validateKey, generateKeys, getAllKeys, deleteKey, toggleKeyStatus } from '../controllers/keyController';
import { requireAuth, requireAdmin } from '../middlewares/authMiddleware';

const router = Router();

// Public key activation endpoint (used by regular app clients)
router.post('/verify', validateKey);

// Admin-only key management
router.post('/generate', requireAuth, requireAdmin, generateKeys);
router.get('/', requireAuth, requireAdmin, getAllKeys);
router.delete('/:keyId', requireAuth, requireAdmin, deleteKey);
router.patch('/:keyId/status', requireAuth, requireAdmin, toggleKeyStatus);

export default router;

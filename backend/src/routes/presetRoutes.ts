import { Router } from 'express';
import { getPresets, createPreset, deletePreset } from '../controllers/presetController';
import { requireAuth, requireAdmin } from '../middlewares/authMiddleware';

const router = Router();

// Retrieve presets dynamically (auth required for any connecting operator)
router.get('/', requireAuth, getPresets);

// Admin-only management endpoints
router.post('/', requireAuth, requireAdmin, createPreset);
router.delete('/:packageId', requireAuth, requireAdmin, deletePreset);

export default router;

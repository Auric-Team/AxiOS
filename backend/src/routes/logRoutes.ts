import { Router } from 'express';
import { getLogs, clearLogs } from '../controllers/logController';
import { requireAuth, requireAdmin } from '../middlewares/authMiddleware';

const router = Router();

// Admin-only logs access
router.get('/', requireAuth, requireAdmin, getLogs);
router.delete('/', requireAuth, requireAdmin, clearLogs);

export default router;

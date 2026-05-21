import { Router } from 'express';
import { login, register, verify, getAllUsers, deleteUser, updateUserRole } from '../controllers/authController';
import { requireAuth, requireAdmin } from '../middlewares/authMiddleware';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.get('/verify', requireAuth, verify);

// Admin-only User Management endpoints
router.get('/users', requireAuth, requireAdmin, getAllUsers);
router.delete('/users/:userId', requireAuth, requireAdmin, deleteUser);
router.patch('/users/:userId/role', requireAuth, requireAdmin, updateUserRole);

export default router;

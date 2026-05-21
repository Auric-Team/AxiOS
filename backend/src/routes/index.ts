import { Router } from 'express';
import authRoutes from './authRoutes';
import deployRoutes from './deployRoutes';
import keyRoutes from './keyRoutes';
import logRoutes from './logRoutes';

const router = Router();

// Map sub-routes under the API prefix
router.use('/', authRoutes);
router.use('/', deployRoutes);
router.use('/keys', keyRoutes);
router.use('/logs', logRoutes);

export default router;

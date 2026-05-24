"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const keyController_1 = require("../controllers/keyController");
const authMiddleware_1 = require("../middlewares/authMiddleware");
const router = (0, express_1.Router)();
// Public key activation endpoint (used by regular app clients)
router.post('/verify', keyController_1.validateKey);
// Admin-only key management
router.post('/generate', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.generateKeys);
router.get('/', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.getAllKeys);
// Bulk actions (must precede parameterized routes)
router.patch('/deactivate-all', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.deactivateAllKeys);
router.delete('/prune-inactive', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.pruneKeys);
// Parameterized routes
router.delete('/:keyId', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.deleteKey);
router.patch('/:keyId', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.updateKey);
router.patch('/:keyId/status', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.toggleKeyStatus);
router.patch('/:keyId/reset-fingerprint', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.resetFingerprint);
exports.default = router;

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
router.delete('/:keyId', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.deleteKey);
router.patch('/:keyId/status', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, keyController_1.toggleKeyStatus);
exports.default = router;

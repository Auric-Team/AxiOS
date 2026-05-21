"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const authController_1 = require("../controllers/authController");
const authMiddleware_1 = require("../middlewares/authMiddleware");
const router = (0, express_1.Router)();
router.post('/register', authController_1.register);
router.post('/login', authController_1.login);
router.get('/verify', authMiddleware_1.requireAuth, authController_1.verify);
// Admin-only User Management endpoints
router.get('/users', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, authController_1.getAllUsers);
router.delete('/users/:userId', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, authController_1.deleteUser);
router.patch('/users/:userId/role', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, authController_1.updateUserRole);
exports.default = router;

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const presetController_1 = require("../controllers/presetController");
const authMiddleware_1 = require("../middlewares/authMiddleware");
const router = (0, express_1.Router)();
// Retrieve presets dynamically (auth required for any connecting operator)
router.get('/', authMiddleware_1.requireAuth, presetController_1.getPresets);
// Admin-only management endpoints
router.post('/', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, presetController_1.createPreset);
router.delete('/:packageId', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, presetController_1.deletePreset);
exports.default = router;

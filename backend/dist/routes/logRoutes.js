"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const logController_1 = require("../controllers/logController");
const authMiddleware_1 = require("../middlewares/authMiddleware");
const router = (0, express_1.Router)();
// Admin-only logs access
router.get('/', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, logController_1.getLogs);
router.delete('/', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, logController_1.clearLogs);
exports.default = router;

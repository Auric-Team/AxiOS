"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const multer_1 = __importDefault(require("multer"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const deployController_1 = require("../controllers/deployController");
const config_1 = __importDefault(require("../config"));
const authMiddleware_1 = require("../middlewares/authMiddleware");
const router = (0, express_1.Router)();
// Configure multer storage structure dynamically to support multi-payload profiles
const storage = multer_1.default.diskStorage({
    destination: (req, file, cb) => {
        const targetGame = (req.query.targetGame || '').trim();
        if (targetGame) {
            const sanitizedGame = targetGame.replace(/[^a-zA-Z0-9._-]/g, '');
            const targetDir = path_1.default.join(config_1.default.uploadDir, 'payloads', sanitizedGame);
            if (!fs_1.default.existsSync(targetDir)) {
                fs_1.default.mkdirSync(targetDir, { recursive: true });
            }
            cb(null, targetDir);
        }
        else {
            cb(null, config_1.default.uploadDir);
        }
    },
    filename: (req, file, cb) => {
        cb(null, 'libil2cpp.so');
    }
});
const upload = (0, multer_1.default)({
    storage: storage,
    limits: { fileSize: 500 * 1024 * 1024 } // 500MB limit
});
router.get('/status', deployController_1.getStatus);
router.get('/download/libil2cpp', deployController_1.downloadBinary);
router.post('/upload', authMiddleware_1.requireAuth, authMiddleware_1.requireAdmin, upload.single('file'), deployController_1.uploadBinary);
exports.default = router;

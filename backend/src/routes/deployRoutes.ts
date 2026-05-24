import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { getStatus, downloadBinary, uploadBinary } from '../controllers/deployController';
import config from '../config';
import { requireAuth, requireAdmin } from '../middlewares/authMiddleware';

const router = Router();

// Configure multer storage structure dynamically to support multi-payload profiles
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const targetGame = (req.query.targetGame as string || '').trim();
    if (targetGame) {
      const sanitizedGame = targetGame.replace(/[^a-zA-Z0-9._-]/g, '');
      const targetDir = path.join(config.uploadDir, 'payloads', sanitizedGame);
      if (!fs.existsSync(targetDir)) {
        fs.mkdirSync(targetDir, { recursive: true });
      }
      cb(null, targetDir);
    } else {
      cb(null, config.uploadDir);
    }
  },
  filename: (req, file, cb) => {
    cb(null, 'libil2cpp.so');
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 500 * 1024 * 1024 } // 500MB limit
});

router.get('/status', getStatus);
router.get('/download/libil2cpp', downloadBinary);
router.post('/upload', requireAuth, requireAdmin, upload.single('file'), uploadBinary);

export default router;

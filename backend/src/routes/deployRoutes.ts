import { Router } from 'express';
import multer from 'multer';
import { getStatus, downloadBinary, uploadBinary } from '../controllers/deployController';
import config from '../config';
import { requireAuth, requireAdmin } from '../middlewares/authMiddleware';

const router = Router();

// Configure multer storage structure
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, config.uploadDir);
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

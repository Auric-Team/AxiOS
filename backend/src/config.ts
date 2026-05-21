import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import os from 'os';

// Load configuration variables from .env file
dotenv.config();

export interface ServerConfig {
  port: number;
  host: string;
  uploadDir: string;
  mockBinary: boolean;
  logLevel: string;
  mongoUri: string;
}

let resolvedUploadDir = path.isAbsolute(process.env.UPLOAD_DIR || 'bin')
  ? (process.env.UPLOAD_DIR || 'bin')
  : path.join(__dirname, '..', process.env.UPLOAD_DIR || 'bin');

// Dynamic check to ensure uploadDir is writable. If not, fallback to OS temporary directory.
try {
  if (!fs.existsSync(resolvedUploadDir)) {
    fs.mkdirSync(resolvedUploadDir, { recursive: true });
  }
  const testFile = path.join(resolvedUploadDir, `.write_test_${Date.now()}`);
  fs.writeFileSync(testFile, 'test');
  fs.unlinkSync(testFile);
} catch (e) {
  const fallbackDir = path.join(os.tmpdir(), 'axios_bin');
  console.warn(`[Config] Configured upload directory (${resolvedUploadDir}) is not writable. Falling back to temporary path: ${fallbackDir}`);
  resolvedUploadDir = fallbackDir;
  try {
    if (!fs.existsSync(resolvedUploadDir)) {
      fs.mkdirSync(resolvedUploadDir, { recursive: true });
    }
  } catch (err) {
    console.error('[Config] Failed to create fallback directory:', err);
  }
}

// Resolve port from multiple env vars (Pterodactyl uses SERVER_PORT, others use PORT)
const resolvedPort = process.env.SERVER_PORT || process.env.PRIMARY_PORT || process.env.APP_PORT || process.env.PORT || '3000';

const config: ServerConfig = {
  port: parseInt(resolvedPort, 10),
  host: process.env.HOST_IP || '0.0.0.0',
  uploadDir: resolvedUploadDir,
  mockBinary: process.env.MOCK_BINARY !== 'false',
  logLevel: process.env.LOG_LEVEL || 'info',
  mongoUri: process.env.MONGO_URI || 'mongodb+srv://Auric:1234@cluster0.ujdtffc.mongodb.net/?retryWrites=true&w=majority',
};

if (isNaN(config.port)) {
  console.warn(`Warning: Invalid PORT env specified. Falling back to default: 3000`);
  config.port = 3000;
}

export default config;


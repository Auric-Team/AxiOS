"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const os_1 = __importDefault(require("os"));
// Load configuration variables from .env file
dotenv_1.default.config();
let resolvedUploadDir = path_1.default.isAbsolute(process.env.UPLOAD_DIR || 'bin')
    ? (process.env.UPLOAD_DIR || 'bin')
    : path_1.default.join(__dirname, '..', process.env.UPLOAD_DIR || 'bin');
// Dynamic check to ensure uploadDir is writable. If not, fallback to OS temporary directory.
try {
    if (!fs_1.default.existsSync(resolvedUploadDir)) {
        fs_1.default.mkdirSync(resolvedUploadDir, { recursive: true });
    }
    const testFile = path_1.default.join(resolvedUploadDir, `.write_test_${Date.now()}`);
    fs_1.default.writeFileSync(testFile, 'test');
    fs_1.default.unlinkSync(testFile);
}
catch (e) {
    const fallbackDir = path_1.default.join(os_1.default.tmpdir(), 'axios_bin');
    console.warn(`[Config] Configured upload directory (${resolvedUploadDir}) is not writable. Falling back to temporary path: ${fallbackDir}`);
    resolvedUploadDir = fallbackDir;
    try {
        if (!fs_1.default.existsSync(resolvedUploadDir)) {
            fs_1.default.mkdirSync(resolvedUploadDir, { recursive: true });
        }
    }
    catch (err) {
        console.error('[Config] Failed to create fallback directory:', err);
    }
}
// Resolve port from multiple env vars (Pterodactyl uses SERVER_PORT, others use PORT)
const resolvedPort = process.env.SERVER_PORT || process.env.PRIMARY_PORT || process.env.APP_PORT || process.env.PORT || '3000';
const config = {
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
exports.default = config;

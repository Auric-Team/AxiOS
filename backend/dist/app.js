"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const config_1 = __importDefault(require("./config"));
const routes_1 = __importDefault(require("./routes"));
const app = (0, express_1.default)();
// Global Middlewares
app.use((0, cors_1.default)());
app.use(express_1.default.json());
// Set up storage directory for binaries
const binDirectory = config_1.default.uploadDir;
if (!fs_1.default.existsSync(binDirectory)) {
    fs_1.default.mkdirSync(binDirectory, { recursive: true });
}
// Generate a mock libil2cpp.so file if enabled
const defaultLibil2cppPath = path_1.default.join(binDirectory, 'libil2cpp.so');
if (config_1.default.mockBinary && !fs_1.default.existsSync(defaultLibil2cppPath)) {
    fs_1.default.writeFileSync(defaultLibil2cppPath, Buffer.from('Mock libil2cpp binary file contents. AxiOS installer payload.', 'utf-8'));
    console.log(`[Config] Created default mock libil2cpp.so at ${defaultLibil2cppPath}`);
}
// Mount the API Router under the /api prefix
app.use('/api', routes_1.default);
// Simple global error fallback handler
app.use((err, req, res, next) => {
    console.error('[App Error] Unhandled Exception:', err);
    res.status(500).json({ error: 'Internal Server Error.' });
});
exports.default = app;

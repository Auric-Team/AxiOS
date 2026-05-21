import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import config from './config';
import apiRouter from './routes';

const app = express();

// Global Middlewares
app.use(cors());
app.use(express.json());

// Set up storage directory for binaries
const binDirectory = config.uploadDir;
if (!fs.existsSync(binDirectory)) {
  fs.mkdirSync(binDirectory, { recursive: true });
}

// Generate a mock libil2cpp.so file if enabled
const defaultLibil2cppPath = path.join(binDirectory, 'libil2cpp.so');
if (config.mockBinary && !fs.existsSync(defaultLibil2cppPath)) {
  fs.writeFileSync(
    defaultLibil2cppPath,
    Buffer.from('Mock libil2cpp binary file contents. AxiOS installer payload.', 'utf-8')
  );
  console.log(`[Config] Created default mock libil2cpp.so at ${defaultLibil2cppPath}`);
}

// Mount the API Router under the /api prefix
app.use('/api', apiRouter);

// Simple global error fallback handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('[App Error] Unhandled Exception:', err);
  res.status(500).json({ error: 'Internal Server Error.' });
});

export default app;

import mongoose, { Document, Schema } from 'mongoose';

export interface ILog extends Document {
  level: 'info' | 'warn' | 'error';
  message: string;
  category: 'auth' | 'key' | 'download' | 'upload' | 'system';
  ip?: string;
  deviceInfo?: string; // Client device brand/model/version
  timestamp: Date;
}

const logSchema = new Schema<ILog>({
  level: { type: String, enum: ['info', 'warn', 'error'], required: true, index: true },
  message: { type: String, required: true },
  category: { type: String, enum: ['auth', 'key', 'download', 'upload', 'system'], required: true, index: true },
  ip: { type: String },
  deviceInfo: { type: String },
  timestamp: { type: Date, default: Date.now, index: true }
});

export const Log = mongoose.model<ILog>('Log', logSchema);

/**
 * Helper to log an event directly to the database.
 */
export async function dbLog(
  level: 'info' | 'warn' | 'error',
  category: 'auth' | 'key' | 'download' | 'upload' | 'system',
  message: string,
  ip?: string,
  deviceInfo?: string
) {
  try {
    await Log.create({ level, category, message, ip, deviceInfo });
    console.log(`[DB Log] [${level.toUpperCase()}] [${category}] ${message}`);
  } catch (err) {
    console.error(`Failed to write log to DB:`, err);
  }
}

export default Log;

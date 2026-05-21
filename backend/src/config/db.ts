import mongoose from 'mongoose';
import config from '../config';

/**
 * Connects to MongoDB Atlas cluster using the environment URI.
 */
export async function connectDatabase(): Promise<void> {
  console.log('[Database] Connecting to MongoDB Atlas...');
  const maxRetries = 5;
  let attempt = 0;

  while (attempt < maxRetries) {
    try {
      await mongoose.connect(config.mongoUri);
      console.log('[Database] Successfully connected to MongoDB Database Cluster.');
      return;
    } catch (error) {
      attempt++;
      console.error(`[Database] Connection attempt ${attempt}/${maxRetries} failed:`, error);
      if (attempt >= maxRetries) {
        console.error('[Database] Critical: Maximum MongoDB connection retries exceeded.');
        process.exit(1);
      }
      // Wait before retrying (2s, 4s, 6s...)
      const delay = attempt * 2000;
      console.log(`[Database] Waiting ${delay / 1000}s before retrying...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}


import { Response } from 'express';
import Log from '../models/Log';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';

/**
 * Admin-only: Fetch system logs with optional filtering.
 */
export async function getLogs(req: AuthenticatedRequest, res: Response) {
  try {
    const { level, category, limit } = req.query;
    
    const filter: any = {};
    if (level) filter.level = level;
    if (category) filter.category = category;

    const limitVal = parseInt((limit as string) || '100', 10);

    const logs = await Log.find(filter)
      .sort({ timestamp: -1 })
      .limit(limitVal);

    res.json({ success: true, logs });
  } catch (e: any) {
    res.status(500).json({ error: 'Failed to fetch logs.' });
  }
}

/**
 * Admin-only: Clear all logs.
 */
export async function clearLogs(req: AuthenticatedRequest, res: Response) {
  try {
    await Log.deleteMany({});
    console.log(`[Admin Log] Logs cleared by ${req.user?.username}`);
    res.json({ success: true, message: 'Logs cleared successfully.' });
  } catch (e: any) {
    res.status(500).json({ error: 'Failed to clear logs.' });
  }
}

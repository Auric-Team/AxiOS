import { Response } from 'express';
import Log from '../models/Log';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';

/**
 * Admin-only: Fetch system logs with pagination and search filtering.
 */
export async function getLogs(req: AuthenticatedRequest, res: Response) {
  try {
    const { level, category, page, limit, search } = req.query;
    
    const filter: any = {};
    
    if (level && level !== 'ALL') {
      filter.level = level;
    }
    
    if (category && category !== 'ALL') {
      filter.category = category;
    }

    if (search) {
      const searchStr = (search as string).trim();
      const escapedSearch = searchStr.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const searchRegex = new RegExp(escapedSearch, 'i');
      filter.$or = [
        { message: searchRegex },
        { ip: searchRegex },
        { deviceInfo: searchRegex }
      ];
    }

    const pageVal = parseInt((page as string) || '1', 10);
    const limitVal = parseInt((limit as string) || '50', 10);
    const skipVal = (pageVal - 1) * limitVal;

    const total = await Log.countDocuments(filter);
    const logs = await Log.find(filter)
      .sort({ timestamp: -1 })
      .skip(skipVal)
      .limit(limitVal);

    res.json({
      success: true,
      logs,
      pagination: {
        total,
        page: pageVal,
        limit: limitVal,
        pages: Math.ceil(total / limitVal)
      }
    });
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

import { Request, Response, NextFunction } from 'express';
import User from '../models/User';

export interface AuthenticatedRequest extends Request {
  user?: {
    username: string;
    role: 'admin' | 'user';
  };
}

/**
 * Middleware validating bearer tokens and appending user payload to Requests.
 */
export async function requireAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Access token required.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = JSON.parse(Buffer.from(token, 'base64').toString('utf8'));
    if (payload.exp < Date.now()) {
      return res.status(401).json({ error: 'Access token expired.' });
    }

    // Verify user exists in the database
    const user = await User.findOne({ username: payload.username });
    if (!user) {
      return res.status(401).json({ error: 'User does not exist.' });
    }

    req.user = { username: user.username, role: user.role };
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid access token.' });
  }
}

/**
 * Middleware restricting access to administrator role only.
 */
export function requireAdmin(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Access denied. Administrative privilege required.' });
  }
  next();
}

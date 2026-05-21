import crypto from 'crypto';

/**
 * Generates a SHA-256 hash of a string.
 * @param text The input string to hash
 */
export function hashPassword(text: string): string {
  return crypto.createHash('sha256').update(text).digest('hex');
}

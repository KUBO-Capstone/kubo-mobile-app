import { randomBytes, scryptSync, timingSafeEqual } from 'crypto';

// Password hashing built on node's crypto so the project gains no native dependency
const KEY_LENGTH = 64;
const SCHEME = 'scrypt';

/** Hashes a plaintext password into a `scrypt$salt$key` string for storage. */
export function hashPassword(password: string): string {
    const salt = randomBytes(16).toString('hex');
    const derivedKey = scryptSync(password, salt, KEY_LENGTH).toString('hex');
    return `${SCHEME}$${salt}$${derivedKey}`;
}

/** Compares a plaintext password against a stored hash in constant time. */
export function verifyPassword(password: string, storedHash: string): boolean {
    const [scheme, salt, key] = storedHash.split('$');
    if (scheme !== SCHEME || !salt || !key) {
        // Rows written before hashing existed are rejected rather than
        // silently compared as plaintext.
        return false;
    }

    const derivedKey = scryptSync(password, salt, KEY_LENGTH);
    const storedKey = Buffer.from(key, 'hex');
    if (derivedKey.length !== storedKey.length) {
        return false;
    }
    return timingSafeEqual(derivedKey, storedKey);
}

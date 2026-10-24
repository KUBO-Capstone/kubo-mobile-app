import crypto from 'crypto';
import { NextFunction, Request, Response } from 'express';

const tokenSecret = process.env.AUTH_TOKEN_SECRET || 'kubo-development-secret-change-me';
if (process.env.NODE_ENV === 'production' && !process.env.AUTH_TOKEN_SECRET) {
    throw new Error('AUTH_TOKEN_SECRET must be configured in production');
}
const tokenLifetimeSeconds = 60 * 60 * 24 * 7;

type TokenPayload = {
    userId: number;
    expiresAt: number;
};

declare global {
    namespace Express {
        interface Request {
            authUserId?: number;
        }
    }
}

const encode = (value: string): string => Buffer.from(value).toString('base64url');

const sign = (value: string): string => crypto
    .createHmac('sha256', tokenSecret)
    .update(value)
    .digest('base64url');

export const createAuthToken = (userId: number): string => {
    const payload: TokenPayload = {
        userId,
        expiresAt: Math.floor(Date.now() / 1000) + tokenLifetimeSeconds,
    };
    const encodedPayload = encode(JSON.stringify(payload));
    return `${encodedPayload}.${sign(encodedPayload)}`;
};

const readToken = (token: string): TokenPayload | null => {
    const [encodedPayload, providedSignature] = token.split('.');
    if (!encodedPayload || !providedSignature) return null;

    const expectedSignature = sign(encodedPayload);
    const provided = Buffer.from(providedSignature);
    const expected = Buffer.from(expectedSignature);
    if (provided.length !== expected.length || !crypto.timingSafeEqual(provided, expected)) return null;

    try {
        const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8')) as TokenPayload;
        if (!Number.isInteger(payload.userId) || payload.expiresAt <= Math.floor(Date.now() / 1000)) return null;
        return payload;
    } catch (_) {
        return null;
    }
};

export const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
    const header = req.header('authorization');
    const token = header?.startsWith('Bearer ') ? header.slice(7) : '';
    const payload = readToken(token);
    if (!payload) {
        res.status(401).json({ success: false, message: 'A valid sign-in session is required' });
        return;
    }
    req.authUserId = payload.userId;
    next();
};

export const attachAuth = (req: Request, _res: Response, next: NextFunction): void => {
    const header = req.header('authorization');
    const token = header?.startsWith('Bearer ') ? header.slice(7) : '';
    const payload = readToken(token);
    if (payload) req.authUserId = payload.userId;
    next();
};

export const requireOwner = (req: Request<{ id: string }>, res: Response, next: NextFunction): void => {
    const requestedUserId = Number(req.params.id);
    if (!Number.isInteger(requestedUserId) || requestedUserId !== req.authUserId) {
        res.status(403).json({ success: false, message: 'You can only change your own profile' });
        return;
    }
    next();
};

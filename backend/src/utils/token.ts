import { createHmac, timingSafeEqual } from 'crypto';

// Signed session tokens built on node's crypto, same reasoning as password.ts:
// no dependency. Shape is `base64url(payload).base64url(hmac-sha256)` - a JWT
// without the header, since there is only ever one algorithm.

export type TokenPayload = {
    /** user_id of the signed-in user. */
    sub: number;
    role: string;
    /** Expiry, seconds since the epoch. */
    exp: number;
};

const TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60;
const DEV_SECRET = 'kubo-dev-secret-change-me';

let warnedAboutSecret = false;

// Read lazily so dotenv.config() in server.ts has run by the time it is needed.
const secret = (): string => {
    const configured = process.env.AUTH_SECRET;
    if (configured) return configured;
    if (!warnedAboutSecret) {
        warnedAboutSecret = true;
        console.warn('AUTH_SECRET is not set; signing tokens with the development secret. Set it in backend/.env.');
    }
    return DEV_SECRET;
};

const sign = (encodedPayload: string): Buffer =>
    createHmac('sha256', secret()).update(encodedPayload).digest();

/** Issues a token for a freshly authenticated user. */
export function signToken(userId: number, role: string): string {
    const payload: TokenPayload = {
        sub: userId,
        role,
        exp: Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS,
    };
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    return `${encodedPayload}.${sign(encodedPayload).toString('base64url')}`;
}

/** Returns the payload of a genuine, unexpired token, or undefined. */
export function verifyToken(token: string): TokenPayload | undefined {
    const [encodedPayload, encodedSignature, extra] = token.split('.');
    if (!encodedPayload || !encodedSignature || extra !== undefined) return undefined;

    const expected = sign(encodedPayload);
    const actual = Buffer.from(encodedSignature, 'base64url');
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return undefined;

    try {
        const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8')) as TokenPayload;
        if (!Number.isInteger(payload.sub) || typeof payload.exp !== 'number') return undefined;
        if (payload.exp <= Math.floor(Date.now() / 1000)) return undefined;
        return payload;
    } catch {
        return undefined;
    }
}

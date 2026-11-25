import { OAuth2Client } from "google-auth-library";
import type { User } from "#models/user.model";

// Sign in with Google: the app gets an ID token from Google's own sign-in
// on the phone and sends it here; this checks it really is Google's and
// decides which Kubo account it opens.
//
// The token's audience (`aud`) is the client ID it was issued for. The phone
// SDKs issue it for the *Web* client ID passed to them as serverClientId, so
// that is the ID GOOGLE_CLIENT_IDS has to hold; more than one (comma
// separated) lets a second Google Cloud project or a staging client in too.

/** What a verified token says about the person signing in. */
export interface GoogleIdentity {
    /** Google's stable account id. Never changes or gets reused, unlike email. */
    sub: string;
    email: string;
    emailVerified: boolean;
    firstName: string;
    lastName: string;
}

/** The token is not a genuine, current Google ID token for this app. */
export class GoogleTokenError extends Error {}

/** The token is genuine, but no account may be opened with it. */
export class GoogleAccountError extends Error {
    constructor(message: string, readonly status: 403 | 409) {
        super(message);
    }
}

/** The client IDs a token may be issued for, from GOOGLE_CLIENT_IDS. */
export const googleClientIds = (): string[] =>
    (process.env.GOOGLE_CLIENT_IDS ?? '').split(',').map((id) => id.trim()).filter(Boolean);

// users.first_name / last_name are varchar(50), email varchar(100).
const NAME_MAX = 50;
const EMAIL_MAX = 100;

/** The part of a verified token's payload that is read. */
export interface GoogleTokenClaims {
    sub?: string;
    email?: string;
    email_verified?: boolean | string;
    given_name?: string;
    family_name?: string;
    name?: string;
}

/** Checks the token with Google's certificates; the payload of a good one. */
export type TokenVerifier = (idToken: string, audience: string[]) => Promise<GoogleTokenClaims | undefined>;

let client: OAuth2Client | undefined;

// google-auth-library checks the RSA signature against Google's published
// certificates (fetched and cached), that iat/exp put the token inside its
// lifetime, that iss is accounts.google.com or https://accounts.google.com,
// and that aud is one of `audience`.
const verifyWithGoogle: TokenVerifier = async (idToken, audience) => {
    client ??= new OAuth2Client();
    const ticket = await client.verifyIdToken({ idToken, audience });
    return ticket.getPayload();
};

const clip = (text: string, max: number): string => text.trim().slice(0, max).trim();

/**
 * Verifies a Google ID token and reads who it is for. Throws
 * GoogleTokenError for anything that is not a genuine, current token issued
 * for one of `audience`. An empty `audience` is refused outright: without it
 * a token minted for any other app would pass.
 */
export async function verifyGoogleIdToken(
    idToken: string,
    audience: string[],
    verify: TokenVerifier = verifyWithGoogle,
): Promise<GoogleIdentity> {
    if (audience.length === 0) throw new GoogleTokenError('No Google client ID is configured');
    let claims: GoogleTokenClaims | undefined;
    try {
        claims = await verify(idToken, audience);
    } catch (error) {
        throw new GoogleTokenError(error instanceof Error ? error.message : String(error));
    }
    const sub = typeof claims?.sub === 'string' ? claims.sub.trim() : '';
    const email = typeof claims?.email === 'string' ? claims.email.trim().toLowerCase() : '';
    if (!sub) throw new GoogleTokenError('Token has no subject');
    if (!email) throw new GoogleTokenError('Token has no email');

    // Older tokens carried "true" as a string.
    const emailVerified = claims?.email_verified === true || claims?.email_verified === 'true';
    let firstName = clip(claims?.given_name ?? '', NAME_MAX);
    let lastName = clip(claims?.family_name ?? '', NAME_MAX);
    if (!firstName) {
        // No given name (some Workspace accounts): use the full name, or the
        // email's local part, so the profile has something to show.
        const [first, ...rest] = (claims?.name?.trim() || email.split('@')[0]).split(/\s+/);
        firstName = clip(first, NAME_MAX);
        if (!lastName) lastName = clip(rest.join(' '), NAME_MAX);
    }
    return { sub, email, emailVerified, firstName, lastName };
}

/** Where Google sign-in reads and writes accounts. */
export interface GoogleUserStore {
    /** The live account already linked to this Google account. */
    findByGoogleSub(sub: string): Promise<User | undefined>;
    findByEmail(email: string): Promise<User | undefined>;
    /** Links the Google account; false when the user is linked to another one already. */
    linkGoogleSub(userId: number, sub: string): Promise<boolean>;
    /** A new Google-only account; undefined when another request created it first. */
    createGoogleUser(identity: GoogleIdentity): Promise<User | undefined>;
}

/**
 * Which account a verified Google identity opens:
 *  1. The account already linked to this Google account (by `sub`).
 *  2. Otherwise only a verified email may go further. An unverified one is
 *     refused: linking it would hand a stranger an existing account, and
 *     creating one with it would let someone claim an address they do not
 *     own, which the real owner's later sign-in would then land in.
 *  3. The account with that email, now linked to this Google account,
 *     unless it is linked to a different Google account already.
 *  4. Otherwise a new account.
 */
export async function resolveGoogleUser(identity: GoogleIdentity, store: GoogleUserStore): Promise<User> {
    // Two first sign-ins at once both get past the lookups; the database's
    // unique indexes let one create the account, and the other goes round
    // once more and finds it.
    for (let attempt = 0; attempt < 2; attempt++) {
        const linked = await store.findByGoogleSub(identity.sub);
        if (linked) return linked;

        if (!identity.emailVerified) {
            throw new GoogleAccountError('Your Google account email is not verified. Verify it with Google, or sign up with email instead.', 403);
        }
        if (identity.email.length > EMAIL_MAX) {
            throw new GoogleAccountError('This Google account email is too long for Kubo. Sign up with email instead.', 403);
        }

        const existing = await store.findByEmail(identity.email);
        if (existing) {
            if (await store.linkGoogleSub(existing.user_id, identity.sub)) return existing;
            // A unique-index clash means this Google account was just linked by
            // a request running alongside; the next round finds it by sub.
            if (await store.findByGoogleSub(identity.sub)) continue;
            throw new GoogleAccountError('This email is already linked to a different Google account. Log in with your email and password.', 409);
        }

        const created = await store.createGoogleUser(identity);
        if (created) return created;
    }
    throw new GoogleAccountError('Could not finish signing in with Google. Please try again.', 409);
}

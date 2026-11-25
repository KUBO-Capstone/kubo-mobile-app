// Sign in with Google: token verification and which account a sign-in opens.
//   npm test
//
// Tokens are real RS256 JWTs signed with a key made here, checked by
// google-auth-library's own verifySignedJwtWithCertsAsync, which is what
// verifyIdToken calls once it has Google's certificates. So the signature,
// exp, iss and aud checks under test are the library's, without asking Google.
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, createSign } from "node:crypto";
import { OAuth2Client } from "google-auth-library";
import {
    GoogleAccountError,
    GoogleIdentity,
    GoogleTokenError,
    GoogleUserStore,
    resolveGoogleUser,
    TokenVerifier,
    verifyGoogleIdToken,
} from "#services/google-auth.service";
import type { User } from "#models/user.model";

const WEB_CLIENT_ID = "1234-web.apps.googleusercontent.com";
const KID = "test-key";

const googleKey = generateKeyPairSync("rsa", { modulusLength: 2048 });
const strangerKey = generateKeyPairSync("rsa", { modulusLength: 2048 });
const publicPem = googleKey.publicKey.export({ type: "spki", format: "pem" }).toString();

const now = () => Math.floor(Date.now() / 1000);
const b64 = (value: object) => Buffer.from(JSON.stringify(value)).toString("base64url");

function signJwt(payload: Record<string, unknown>, key = googleKey.privateKey): string {
    const unsigned = `${b64({ alg: "RS256", typ: "JWT", kid: KID })}.${b64(payload)}`;
    const signature = createSign("RSA-SHA256").update(unsigned).sign(key).toString("base64url");
    return `${unsigned}.${signature}`;
}

const claims = (overrides: Record<string, unknown> = {}) => ({
    iss: "https://accounts.google.com",
    aud: WEB_CLIENT_ID,
    sub: "110000000000000000001",
    email: "Juan.DelaCruz@gmail.com",
    email_verified: true,
    given_name: "Juan",
    family_name: "Dela Cruz",
    iat: now() - 10,
    exp: now() + 3600,
    ...overrides,
});

// The library's checks, with this test's key standing in for Google's.
const libraryVerifier: TokenVerifier = async (idToken, audience) => {
    const client = new OAuth2Client();
    const ticket = await client.verifySignedJwtWithCertsAsync(
        idToken, { [KID]: publicPem }, audience, ["accounts.google.com", "https://accounts.google.com"]);
    return ticket.getPayload();
};

const verify = (token: string, audience = [WEB_CLIENT_ID]) => verifyGoogleIdToken(token, audience, libraryVerifier);

describe("verifyGoogleIdToken", () => {
    test("reads a genuine token", async () => {
        const identity = await verify(signJwt(claims()));
        assert.deepEqual(identity, {
            sub: "110000000000000000001",
            email: "juan.delacruz@gmail.com",
            emailVerified: true,
            firstName: "Juan",
            lastName: "Dela Cruz",
        });
    });

    test("accepts the issuer without https too", async () => {
        await verify(signJwt(claims({ iss: "accounts.google.com" })));
    });

    test("accepts any of several configured client IDs", async () => {
        await verify(signJwt(claims({ aud: "second-web.apps.googleusercontent.com" })),
            [WEB_CLIENT_ID, "second-web.apps.googleusercontent.com"]);
    });

    test("rejects a token signed by another key", async () => {
        await assert.rejects(verify(signJwt(claims(), strangerKey.privateKey)), GoogleTokenError);
    });

    test("rejects a token whose payload was changed after signing", async () => {
        const [header, , signature] = signJwt(claims()).split(".");
        const forged = `${header}.${b64(claims({ email: "someone.else@gmail.com" }))}.${signature}`;
        await assert.rejects(verify(forged), GoogleTokenError);
    });

    test("rejects an expired token", async () => {
        await assert.rejects(verify(signJwt(claims({ iat: now() - 7200, exp: now() - 3600 }))), /too late/);
    });

    test("rejects a token for another app's client ID", async () => {
        await assert.rejects(verify(signJwt(claims({ aud: "someone-elses-app.apps.googleusercontent.com" }))), /recipient/);
    });

    test("rejects a token from another issuer", async () => {
        await assert.rejects(verify(signJwt(claims({ iss: "https://evil.example.com" }))), /issuer/);
    });

    test("refuses every token when no client ID is configured", async () => {
        let called = false;
        const spy: TokenVerifier = async () => { called = true; return claims(); };
        await assert.rejects(verifyGoogleIdToken(signJwt(claims()), [], spy), GoogleTokenError);
        assert.equal(called, false);
    });

    test("rejects a token without sub or email", async () => {
        await assert.rejects(verify(signJwt(claims({ sub: undefined }))), /subject/);
        await assert.rejects(verify(signJwt(claims({ email: undefined }))), /email/);
    });

    test("email_verified: only true or \"true\" count", async () => {
        assert.equal((await verify(signJwt(claims({ email_verified: "true" })))).emailVerified, true);
        assert.equal((await verify(signJwt(claims({ email_verified: false })))).emailVerified, false);
        assert.equal((await verify(signJwt(claims({ email_verified: undefined })))).emailVerified, false);
    });

    test("falls back to the full name, then the email, for a missing given name", async () => {
        const fromName = await verify(signJwt(claims({ given_name: undefined, family_name: undefined, name: "Maria Clara Santos" })));
        assert.equal(fromName.firstName, "Maria");
        assert.equal(fromName.lastName, "Clara Santos");
        const fromEmail = await verify(signJwt(claims({ given_name: undefined, family_name: undefined })));
        assert.equal(fromEmail.firstName, "juan.delacruz");
        assert.equal(fromEmail.lastName, "");
    });

    test("clips names to the column length", async () => {
        const identity = await verify(signJwt(claims({ given_name: "A".repeat(80) })));
        assert.equal(identity.firstName.length, 50);
    });
});

// --- account linking --------------------------------------------------------

type Row = User & { google_sub: string | null };

class MemoryStore implements GoogleUserStore {
    rows: Row[] = [];
    /** Makes the next create behave as if another request beat it to it. */
    loseNextCreateTo?: Row;

    add(email: string, google_sub: string | null = null): Row {
        const row = {
            user_id: this.rows.length + 1, first_name: "Existing", last_name: "User", email, google_sub,
            password_hash: "scrypt$salt$key", contact_number: "09171234567", role: "consumer",
        } as Row;
        this.rows.push(row);
        return row;
    }

    async findByGoogleSub(sub: string) { return this.rows.find((row) => row.google_sub === sub); }

    async findByEmail(email: string) { return this.rows.find((row) => row.email.toLowerCase() === email.toLowerCase()); }

    async linkGoogleSub(userId: number, sub: string) {
        const row = this.rows.find((r) => r.user_id === userId);
        if (!row || row.google_sub !== null || this.rows.some((r) => r.google_sub === sub)) return false;
        row.google_sub = sub;
        return true;
    }

    async createGoogleUser(identity: GoogleIdentity) {
        if (this.loseNextCreateTo) {
            this.rows.push(this.loseNextCreateTo);
            this.loseNextCreateTo = undefined;
            return undefined;
        }
        if (this.rows.some((r) => r.email === identity.email || r.google_sub === identity.sub)) return undefined;
        const row = { ...this.add(identity.email, identity.sub), first_name: identity.firstName, last_name: identity.lastName, password_hash: "", contact_number: "" };
        this.rows[this.rows.length - 1] = row;
        return row;
    }
}

const identity = (overrides: Partial<GoogleIdentity> = {}): GoogleIdentity => ({
    sub: "google-sub-1", email: "juan@gmail.com", emailVerified: true, firstName: "Juan", lastName: "Dela Cruz", ...overrides,
});

const rejectsWith = (status: number) => (error: unknown) => error instanceof GoogleAccountError && error.status === status;

describe("resolveGoogleUser", () => {
    test("new person: creates a Google-only account with no password", async () => {
        const store = new MemoryStore();
        const user = await resolveGoogleUser(identity(), store);
        assert.equal(store.rows.length, 1);
        assert.equal(user.email, "juan@gmail.com");
        assert.equal(user.first_name, "Juan");
        assert.equal(user.password_hash, "");
        assert.equal(store.rows[0].google_sub, "google-sub-1");
    });

    test("returning person: the account linked to their sub, nothing new created", async () => {
        const store = new MemoryStore();
        const first = await resolveGoogleUser(identity(), store);
        const again = await resolveGoogleUser(identity(), store);
        assert.equal(again.user_id, first.user_id);
        assert.equal(store.rows.length, 1);
    });

    test("returning person whose Google email changed: still found by sub", async () => {
        const store = new MemoryStore();
        const first = await resolveGoogleUser(identity(), store);
        const again = await resolveGoogleUser(identity({ email: "juan.new@gmail.com" }), store);
        assert.equal(again.user_id, first.user_id);
        assert.equal(store.rows.length, 1);
    });

    test("linked account opens even if Google now says the email is unverified", async () => {
        const store = new MemoryStore();
        const existing = store.add("juan@gmail.com", "google-sub-1");
        const user = await resolveGoogleUser(identity({ emailVerified: false }), store);
        assert.equal(user.user_id, existing.user_id);
    });

    test("existing email account + verified Google email: linked, not duplicated", async () => {
        const store = new MemoryStore();
        const existing = store.add("Juan@Gmail.com");
        const user = await resolveGoogleUser(identity(), store);
        assert.equal(user.user_id, existing.user_id);
        assert.equal(existing.google_sub, "google-sub-1");
        assert.equal(existing.password_hash, "scrypt$salt$key", "the password still works");
        assert.equal(store.rows.length, 1);
    });

    test("existing email account + unverified Google email: refused, not linked", async () => {
        const store = new MemoryStore();
        const existing = store.add("juan@gmail.com");
        await assert.rejects(resolveGoogleUser(identity({ emailVerified: false }), store), rejectsWith(403));
        assert.equal(existing.google_sub, null);
        assert.equal(store.rows.length, 1);
    });

    test("new person with an unverified Google email: refused, nothing created", async () => {
        const store = new MemoryStore();
        await assert.rejects(resolveGoogleUser(identity({ emailVerified: false }), store), rejectsWith(403));
        assert.equal(store.rows.length, 0);
    });

    test("email already linked to a different Google account: refused", async () => {
        const store = new MemoryStore();
        const existing = store.add("juan@gmail.com", "some-other-google-sub");
        await assert.rejects(resolveGoogleUser(identity(), store), rejectsWith(409));
        assert.equal(existing.google_sub, "some-other-google-sub");
    });

    test("email too long for users.email: refused", async () => {
        const store = new MemoryStore();
        await assert.rejects(resolveGoogleUser(identity({ email: `${"a".repeat(95)}@gmail.com` }), store), rejectsWith(403));
    });

    test("two first sign-ins at once: the one that loses the insert finds the winner's account", async () => {
        const store = new MemoryStore();
        const winner = { user_id: 7, email: "juan@gmail.com", google_sub: "google-sub-1", password_hash: "" } as Row;
        store.loseNextCreateTo = winner;
        const user = await resolveGoogleUser(identity(), store);
        assert.equal(user.user_id, 7);
        assert.equal(store.rows.length, 1);
    });

    test("two links at once: the one that loses the update finds the linked account", async () => {
        const store = new MemoryStore();
        const existing = store.add("juan@gmail.com");
        const realLink = store.linkGoogleSub.bind(store);
        store.linkGoogleSub = async (userId, sub) => {
            existing.google_sub = sub; // the other request got there first
            return realLink(userId, sub);
        };
        const user = await resolveGoogleUser(identity(), store);
        assert.equal(user.user_id, existing.user_id);
    });
});

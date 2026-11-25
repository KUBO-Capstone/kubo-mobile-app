import { Request, Response } from "express";
import { UserModel } from "#models/user.model";
import { authUserId } from "#middleware/auth.middleware";
import { verifyPassword } from "#utils/password";
import { signToken } from "#utils/token";
import { GoogleAccountError, GoogleIdentity, googleClientIds, resolveGoogleUser, verifyGoogleIdToken } from "#services/google-auth.service";

// The signed-in user behind a saved token, in the same shape login answers
// with. The app calls this when it reopens with a session it kept from last
// time: the row is whatever it is now (name, photo), and the token is a new
// one, so someone who keeps using the app is never signed out by the token's
// expiry. Mounted behind requireAuth, which is what turns a token that has
// expired or belongs to a deleted account into a 401.
export const me = async (_req: Request, res: Response): Promise<void> => {
	const user = await UserModel.findById(authUserId(res));
	if (!user) {
		res.status(404).json({ success: false, message: "User not found" });
		return;
	}
	const { password_hash: _passwordHash, ...safeUser } = user;
	res.json({ success: true, data: { ...safeUser, token: signToken(user.user_id, user.role) } });
};

export const login = async (req: Request, res: Response): Promise<void> => {
	const email = typeof req.body.email === "string" ? req.body.email.trim().toLowerCase() : "";
	const password = typeof req.body.password === "string" ? req.body.password : "";
	const user = await UserModel.findByEmail(email);

	if (!user || !verifyPassword(password, user.password_hash)) {
		res.status(401).json({ success: false, message: "Invalid email or password" });
		return;
	}

	const { password_hash: _passwordHash, ...safeUser } = user;
	// The token rides along on the user row; the app strips it into its session.
	res.json({ success: true, data: { ...safeUser, token: signToken(user.user_id, user.role) } });
};

// Sign in with Google. The app sends the ID token Google's sign-in on the
// phone gave it; the answer is the same user row + token as login, so the
// app starts the session the same way whichever button was used.
export const googleLogin = async (req: Request, res: Response): Promise<void> => {
	const idToken = typeof req.body?.id_token === "string" ? req.body.id_token.trim() : "";
	if (!idToken) {
		res.status(400).json({ success: false, message: "Missing Google sign-in token" });
		return;
	}
	const audience = googleClientIds();
	if (audience.length === 0) {
		console.error("POST /auth/google: GOOGLE_CLIENT_IDS is not set in backend/.env");
		res.status(503).json({ success: false, message: "Google sign-in is not available right now" });
		return;
	}

	let identity: GoogleIdentity;
	try {
		identity = await verifyGoogleIdToken(idToken, audience);
	} catch (error) {
		// Logged for setup problems (a wrong client ID shows here as an
		// audience mismatch); the app only hears that it did not work.
		console.warn("Google ID token rejected:", error instanceof Error ? error.message : error);
		res.status(401).json({ success: false, message: "Google sign-in could not be verified. Please try again." });
		return;
	}

	try {
		const user = await resolveGoogleUser(identity, UserModel.google);
		const { password_hash: _passwordHash, ...safeUser } = user;
		res.json({ success: true, data: { ...safeUser, token: signToken(user.user_id, user.role) } });
	} catch (error) {
		if (error instanceof GoogleAccountError) {
			res.status(error.status).json({ success: false, message: error.message });
			return;
		}
		throw error;
	}
};

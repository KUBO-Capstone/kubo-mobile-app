import { Request, Response } from "express";
import { UserModel } from "#models/user.model";
import { verifyPassword } from "#utils/password";
import { signToken } from "#utils/token";

export const login = (req: Request, res: Response): void => {
	const email = typeof req.body.email === "string" ? req.body.email.trim().toLowerCase() : "";
	const password = typeof req.body.password === "string" ? req.body.password : "";
	const user = UserModel.findByEmail(email);

	if (!user || !verifyPassword(password, user.password_hash)) {
		res.status(401).json({ success: false, message: "Invalid email or password" });
		return;
	}

	const { password_hash: _passwordHash, ...safeUser } = user;
	// The token rides along on the user row; the app strips it into its session.
	res.json({ success: true, data: { ...safeUser, token: signToken(user.user_id, user.role) } });
};

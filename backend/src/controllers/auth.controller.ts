import { Request, Response } from "express";
import { UserModel } from "#models/user.model";
import { verifyPassword } from "#utils/password";
import { createAuthToken } from "#middleware/auth.middleware";

export const login = (req: Request, res: Response): void => {
	const email = typeof req.body.email === "string" ? req.body.email.trim().toLowerCase() : "";
	const password = typeof req.body.password === "string" ? req.body.password : "";
	const user = UserModel.findByEmail(email);

	if (!user || !verifyPassword(password, user.password_hash)) {
		res.status(401).json({ success: false, message: "Invalid email or password" });
		return;
	}

	const { password_hash: _passwordHash, ...safeUser } = user;
	res.json({ success: true, data: { ...safeUser, access_token: createAuthToken(user.user_id) } });
};

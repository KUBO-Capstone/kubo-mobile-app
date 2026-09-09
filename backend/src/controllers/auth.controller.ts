import { Request, Response } from "express";
import { UserModel } from "#models/user.model";

export const login = (req: Request, res: Response): void => {
	const email = typeof req.body.email === "string" ? req.body.email.trim().toLowerCase() : "";
	const password = typeof req.body.password === "string" ? req.body.password : "";
	const user = UserModel.findByEmail(email);

	if (!user || user.password !== password) {
		res.status(401).json({ success: false, message: "Invalid email or password" });
		return;
	}

	const { password: _password, ...safeUser } = user;
	res.json({ success: true, data: safeUser });
};

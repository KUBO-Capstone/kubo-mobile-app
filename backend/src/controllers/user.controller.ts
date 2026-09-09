import { Request, Response } from "express";
import { UserModel } from "#models/user.model";

export const getUsers = (req: Request, res: Response): void => {
    const users = UserModel.findAll();
    res.json({
        success: true,
        data: users.map(({ password: _password, ...user }) => user),
    });
};

export const createUser = (req: Request, res: Response): void => {
    const { first_name, last_name, email, password, contact_number } = req.body;

    if (!first_name || !last_name || !email || !password || !contact_number) {
        res.status(400).json({ success: false, message: "All user fields are required" });
        return;
    }

    const normalizedEmail = email.trim().toLowerCase();
    if (UserModel.findByEmail(normalizedEmail)) {
        res.status(409).json({ success: false, message: "An account with this email already exists" });
        return;
    }

    const user = UserModel.create({ first_name, last_name, email: normalizedEmail, password, contact_number });
    const { password: _password, ...safeUser } = user;
    res.status(201).json({ success: true, data: safeUser });
};
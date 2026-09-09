import { Request, Response } from "express";
import { UserModel } from "#models/user.model";

export const getUsers = (req: Request, res: Response): void => {
    const users = UserModel.findAll();
    res.json({ success: true, data: users });
};

export const createUser = (req: Request, res: Response): void => {
    const { first_name, last_name, email, password, contact_number } = req.body;
    const user = UserModel.create({ first_name, last_name, email, password, contact_number });
    res.status(201).json({ success: true, data: user });
};
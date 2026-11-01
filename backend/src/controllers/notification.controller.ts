import { Request, Response } from "express";
import { authUserId } from "#middleware/auth.middleware";
import { NotificationModel } from "#models/notification.model";

export const getNotifications = async (_req: Request, res: Response): Promise<void> => {
    res.json({ success: true, data: await NotificationModel.findForUser(authUserId(res)) });
};
import { Request, Response } from "express";
import { authUserId } from "#middleware/auth.middleware";
import { NotificationModel } from "#models/notification.model";

export const getNotifications = (_req: Request, res: Response): void => {
    res.json({ success: true, data: NotificationModel.findForUser(authUserId(res)) });
};
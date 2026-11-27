import { Request, Response } from "express";
import { authUserId } from "#middleware/auth.middleware";
import { NotificationModel } from "#models/notification.model";

export const getNotifications = async (_req: Request, res: Response): Promise<void> => {
    res.json({ success: true, data: await NotificationModel.findForUser(authUserId(res)) });
};

// The bell's badge.
export const getUnreadNotificationCount = async (_req: Request, res: Response): Promise<void> => {
    res.json({ success: true, data: { unread: await NotificationModel.countUnread(authUserId(res)) } });
};

// Opening a notification marks it read.
export const markNotificationRead = async (req: Request, res: Response): Promise<void> => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
        res.status(400).json({ success: false, message: 'Invalid notification id' });
        return;
    }
    if (!(await NotificationModel.markRead(authUserId(res), id))) {
        res.status(404).json({ success: false, message: 'Notification not found' });
        return;
    }
    res.json({ success: true, data: { notification_id: id, is_read: true } });
};

// "Mark All as Read" on the notifications page.
export const markAllNotificationsRead = async (_req: Request, res: Response): Promise<void> => {
    const updated = await NotificationModel.markAllRead(authUserId(res));
    res.json({ success: true, data: { marked_read: updated } });
};

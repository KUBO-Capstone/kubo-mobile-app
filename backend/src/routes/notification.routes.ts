import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import {
    getNotifications,
    getUnreadNotificationCount,
    markAllNotificationsRead,
    markNotificationRead,
} from "#controllers/notification.controller";

const router = Router();
router.use(requireAuth);
router.get('/', getNotifications);
router.get('/unread-count', getUnreadNotificationCount);
router.patch('/read', markAllNotificationsRead);
router.patch('/:id/read', markNotificationRead);

export default router;

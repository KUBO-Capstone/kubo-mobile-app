import { db } from "#config/database";

export interface Notification {
    notification_id: number;
    sender: { id: number; name: string; email: string } | null;
    recipient: { id: number; name: string; email: string };
    product: {
        id: number;
        name: string;
        category: string;
        price: number;
        quantity: number;
        unit: string;
        status: string;
        image: string | null;
    } | null;
    title: string;
    message: string;
    is_read: boolean;
    created_at: string;
}

const mapNotification = (row: Record<string, unknown>): Notification => ({
    notification_id: Number(row.notification_id),
    sender: row.sender_id === null ? null : {
        id: Number(row.sender_id),
        name: String(row.sender_name),
        email: String(row.sender_email),
    },
    recipient: {
        id: Number(row.recipient_id),
        name: String(row.recipient_name),
        email: String(row.recipient_email),
    },
    product: row.product_id === null ? null : {
        id: Number(row.product_id),
        name: String(row.product_name),
        category: String(row.product_category),
        price: Number(row.product_price),
        quantity: Number(row.product_quantity),
        unit: String(row.product_unit),
        status: String(row.product_status),
        image: row.product_image === null ? null : String(row.product_image),
    },
    title: String(row.title),
    message: String(row.message),
    is_read: Boolean(row.is_read),
    created_at: String(row.created_at),
});

export const NotificationModel = {
    findForUser(recipientId: number): Notification[] {
        const rows = db.prepare(`
                SELECT n.notification_id, n.sender_id, n.recipient_id, n.product_id,
                   n.title, n.message, n.is_read, n.created_at,
                   s.first_name || ' ' || s.last_name AS sender_name,
                   s.email AS sender_email,
                   r.first_name || ' ' || r.last_name AS recipient_name,
                   r.email AS recipient_email,
                   p.crop_name AS product_name,
                   p.category AS product_category,
                   p.base_price AS product_price,
                   p.available_quantity AS product_quantity,
                   p.unit_measurement AS product_unit,
                   p.status AS product_status,
                   (SELECT pi.image_url FROM product_images pi
                    WHERE pi.product_id = p.product_id
                    ORDER BY pi.display_order LIMIT 1) AS product_image
                FROM notifications n
                JOIN users r ON r.user_id = n.recipient_id
                LEFT JOIN users s ON s.user_id = n.sender_id
                LEFT JOIN products p ON p.product_id = n.product_id
                WHERE n.recipient_id = @recipientId
                ORDER BY n.created_at DESC, n.notification_id DESC
        `).all({ recipientId }) as Record<string, unknown>[];
        return rows.map(mapNotification);
    },

    create(input: {
        recipientId: number;
        senderId: number;
        productId: number | null;
        title: string;
        message: string;
    }): void {
        db.prepare(`
            INSERT INTO notifications (recipient_id, sender_id, product_id, title, message)
            VALUES (@recipientId, @senderId, @productId, @title, @message)
        `).run(input);
    },
};
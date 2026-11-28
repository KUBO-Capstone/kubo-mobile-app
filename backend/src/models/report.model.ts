import { isRowId, isUniqueViolation, pool } from "#database/pg";
import { UserModel } from "#models/user.model";
import type { ReportStore } from "#services/moderation-report.service";

export type ReportCategory = 'feedback' | 'bug' | 'other';

export const ReportModel = {
    async create(input: {
        senderId: number;
        name: string;
        category: ReportCategory;
        message: string;
    }): Promise<number> {
        const { rows } = await pool.query(`
            INSERT INTO reports (sender_id, name, category, message)
            VALUES ($1, $2, $3, $4)
            RETURNING report_id
        `, [input.senderId, input.name, input.category, input.message]);
        return Number(rows[0].report_id);
    },
};

/** Reports of a listing or an account (moderation_reports). */
export const moderationReportStore: ReportStore = {
    async findListingSeller(productId) {
        if (!isRowId(productId)) return undefined;
        const { rows } = await pool.query(
            `SELECT seller_id FROM products WHERE product_id = $1 AND status <> 'delisted'`, [productId]);
        return rows[0] ? Number(rows[0].seller_id) : undefined;
    },

    isActiveUser: (userId) => UserModel.isActive(userId),

    async insert({ reporterId, reportedUserId, productId, reason }) {
        try {
            const { rows } = await pool.query(`
                INSERT INTO moderation_reports (reporter_id, reported_user_id, product_id, reason)
                VALUES ($1, $2, $3, $4)
                RETURNING report_id
            `, [reporterId, reportedUserId, productId, reason]);
            return Number(rows[0].report_id);
        } catch (error) {
            if (isUniqueViolation(error, 'uq_moderation_reports_open_listing')
                || isUniqueViolation(error, 'uq_moderation_reports_open_profile')) return undefined;
            throw error;
        }
    },
};

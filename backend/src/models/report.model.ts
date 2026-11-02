import { pool } from "#database/pg";

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
import { db } from "#config/database";

export type ReportCategory = 'feedback' | 'bug' | 'other';

export const ReportModel = {
    create(input: {
        senderId: number;
        name: string;
        category: ReportCategory;
        message: string;
    }): number {
        const result = db.prepare(`
            INSERT INTO reports (sender_id, name, category, message)
            VALUES (@senderId, @name, @category, @message)
        `).run(input);
        return Number(result.lastInsertRowid);
    },
};
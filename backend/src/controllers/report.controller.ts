import { Request, Response } from "express";
import { authUserId } from "#middleware/auth.middleware";
import { ReportCategory, ReportModel } from "#models/report.model";

const categories = new Set<ReportCategory>(['feedback', 'bug', 'other']);

export const createReport = (req: Request, res: Response): void => {
    const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
    const message = typeof req.body.message === 'string' ? req.body.message.trim() : '';
    const category = typeof req.body.category === 'string' && categories.has(req.body.category)
        ? req.body.category as ReportCategory
        : 'feedback';

    if (!name || !message) {
        res.status(400).json({ success: false, message: 'A subject and message are required' });
        return;
    }
    if (name.length > 120 || message.length > 2000) {
        res.status(400).json({ success: false, message: 'The subject or message is too long' });
        return;
    }

    const reportId = ReportModel.create({
        senderId: authUserId(res),
        name,
        category,
        message,
    });
    res.status(201).json({ success: true, data: { report_id: reportId } });
};
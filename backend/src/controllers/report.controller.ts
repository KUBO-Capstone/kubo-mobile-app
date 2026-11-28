import { Request, Response } from "express";
import { authUserId } from "#middleware/auth.middleware";
import { moderationReportStore, ReportCategory, ReportModel } from "#models/report.model";
import { fileReport, ReportError, ReportTarget } from "#services/moderation-report.service";

const categories = new Set<ReportCategory>(['feedback', 'bug', 'other']);

export const createReport = async (req: Request, res: Response): Promise<void> => {
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

    const reportId = await ReportModel.create({
        senderId: authUserId(res),
        name,
        category,
        message,
    });
    res.status(201).json({ success: true, data: { report_id: reportId } });
};

async function reportTarget(req: Request<{ id: string }>, res: Response, target: ReportTarget): Promise<void> {
    try {
        const reportId = await fileReport(authUserId(res), target, req.body?.reason, moderationReportStore);
        res.status(201).json({ success: true, data: { report_id: reportId } });
    } catch (error) {
        if (error instanceof ReportError) {
            res.status(error.status).json({ success: false, message: error.message });
            return;
        }
        throw error;
    }
}

/** POST /reports/listings/:id { reason } */
export const reportListing = (req: Request<{ id: string }>, res: Response): Promise<void> =>
    reportTarget(req, res, { kind: 'listing', productId: Number(req.params.id) });

/** POST /reports/users/:id { reason } */
export const reportUser = (req: Request<{ id: string }>, res: Response): Promise<void> =>
    reportTarget(req, res, { kind: 'user', userId: Number(req.params.id) });

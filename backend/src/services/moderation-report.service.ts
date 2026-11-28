// Reporting a listing or an account (moderation_reports, migration 010).

/** The longest reason accepted; mirrors the CHECK on moderation_reports.reason. */
export const REPORT_REASON_MAX = 1000;

export class ReportError extends Error {
    constructor(message: string, readonly status: number) {
        super(message);
    }
}

export interface ReportStore {
    /** The listing's seller, or undefined when there is no such listing (or it was removed). */
    findListingSeller(productId: number): Promise<number | undefined>;
    /** Whether the account exists and has not been deleted. */
    isActiveUser(userId: number): Promise<boolean>;
    /** The new report's id; undefined when the reporter already has an open one on it. */
    insert(report: { reporterId: number; reportedUserId: number; productId: number | null; reason: string }): Promise<number | undefined>;
}

export type ReportTarget = { kind: 'listing'; productId: number } | { kind: 'user'; userId: number };

function cleanReason(reason: unknown): string {
    const text = typeof reason === 'string' ? reason.trim() : '';
    if (!text) throw new ReportError('Tell us why you are reporting this.', 400);
    if (text.length > REPORT_REASON_MAX) throw new ReportError(`Keep the reason under ${REPORT_REASON_MAX} characters.`, 400);
    return text;
}

/**
 * Files a report and returns its id. Refuses a reason that is empty or too
 * long, a listing or account that is not there, reporting yourself or your
 * own listing, and a second open report on the same thing.
 */
export async function fileReport(reporterId: number, target: ReportTarget, reason: unknown, store: ReportStore): Promise<number> {
    const text = cleanReason(reason);

    let reportedUserId: number;
    let productId: number | null = null;
    if (target.kind === 'listing') {
        const sellerId = await store.findListingSeller(target.productId);
        if (sellerId === undefined) throw new ReportError('This listing is no longer available.', 404);
        if (sellerId === reporterId) throw new ReportError('You cannot report your own listing.', 400);
        reportedUserId = sellerId;
        productId = target.productId;
    } else {
        if (target.userId === reporterId) throw new ReportError('You cannot report your own profile.', 400);
        if (!(await store.isActiveUser(target.userId))) throw new ReportError('This account is no longer available.', 404);
        reportedUserId = target.userId;
    }

    const reportId = await store.insert({ reporterId, reportedUserId, productId, reason: text });
    if (reportId === undefined) {
        throw new ReportError(
            target.kind === 'listing'
                ? 'You have already reported this listing. We are looking into it.'
                : 'You have already reported this profile. We are looking into it.',
            409,
        );
    }
    return reportId;
}

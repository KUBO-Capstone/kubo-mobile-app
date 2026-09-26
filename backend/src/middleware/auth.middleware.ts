import { NextFunction, Request, Response } from "express";
import { verifyToken } from "#utils/token";
import { UserModel } from "#models/user.model";

// Every route behind requireAuth takes the acting user from the bearer token
// and nowhere else - ids in the body or query are no longer identity.

/**
 * Rejects the request with 401 unless it carries `Authorization: Bearer <token>`
 * for a user that still exists; on success the caller is `authUserId(res)`.
 */
export const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
    const header = req.headers.authorization ?? '';
    const [scheme, token] = header.split(' ');
    const payload = scheme === 'Bearer' && token ? verifyToken(token) : undefined;
    if (!payload || !UserModel.findById(payload.sub)) {
        res.status(401).json({ success: false, message: 'Your session has expired. Please log in again.' });
        return;
    }
    res.locals.userId = payload.sub;
    next();
};

/** The signed-in user's id. Only valid on routes mounted behind requireAuth. */
export const authUserId = (res: Response): number => res.locals.userId as number;

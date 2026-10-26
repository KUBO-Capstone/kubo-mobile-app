import { NextFunction, Request, Response } from "express";
import { verifyToken } from "#utils/token";
import { UserModel } from "#models/user.model";

declare global {
    namespace Express {
        interface Request {
            authUserId?: number;
        }
    }
}

export const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
    const header = req.headers.authorization ?? '';
    const [scheme, token] = header.split(' ');
    const payload = scheme === 'Bearer' && token ? verifyToken(token) : undefined;
    if (!payload || !UserModel.findById(payload.sub)) {
        res.status(401).json({ success: false, message: 'Your session has expired. Please log in again.' });
        return;
    }
    req.authUserId = payload.sub;
    res.locals.userId = payload.sub;
    next();
};

export const attachAuth = (req: Request, _res: Response, next: NextFunction): void => {
    const header = req.headers.authorization ?? '';
    const [scheme, token] = header.split(' ');
    const payload = scheme === 'Bearer' && token ? verifyToken(token) : undefined;
    if (payload && UserModel.findById(payload.sub)) req.authUserId = payload.sub;
    next();
};

export const requireOwner = (req: Request<{ id: string }>, res: Response, next: NextFunction): void => {
    const requestedUserId = Number(req.params.id);
    if (!Number.isInteger(requestedUserId) || requestedUserId !== req.authUserId) {
        res.status(403).json({ success: false, message: 'You can only change your own profile' });
        return;
    }
    next();
};

export const authUserId = (res: Response): number => res.locals.userId as number;

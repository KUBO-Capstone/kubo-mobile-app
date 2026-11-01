import { Request, Response } from "express";
import { EarningsModel } from "#models/earnings.model";

// GET /users/:id/earnings - behind requireAuth + requireOwner: the figures
// are only ever shown to the seller themselves.
export const getEarnings = async (req: Request<{ id: string }>, res: Response): Promise<void> => {
    res.json({ success: true, data: await EarningsModel.forSeller(Number(req.params.id)) });
};

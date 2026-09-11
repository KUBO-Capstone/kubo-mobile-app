import { Request, Response } from "express";
import { BagsakanModel } from "#models/bagsakan.model";

export const getBagsakanCenters = (req: Request, res: Response): void => {
    const query = typeof req.query.q === 'string' ? req.query.q : '';
    res.json({ success: true, data: BagsakanModel.findAll(query) });
};

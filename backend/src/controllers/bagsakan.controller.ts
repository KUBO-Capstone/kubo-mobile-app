import { Request, Response } from "express";
import { BagsakanModel } from "#models/bagsakan.model";

export const getBagsakanCenters = async (req: Request, res: Response): Promise<void> => {
    const query = typeof req.query.q === 'string' ? req.query.q : '';
    res.json({ success: true, data: await BagsakanModel.findAll(query) });
};

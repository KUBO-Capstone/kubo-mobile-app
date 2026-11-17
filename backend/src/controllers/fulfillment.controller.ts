import { Request, Response } from "express";
import { Courier, FulfillmentModel, isCourier } from "#models/fulfillment.model";
import { BagsakanModel } from "#models/bagsakan.model";
import { ProductModel } from "#models/product.model";
import { UserModel } from "#models/user.model";
import { authUserId } from "#middleware/auth.middleware";

type Parsed<T> = { value: T; error?: undefined; status?: undefined } | { value?: undefined; error: string; status: number };

// Reads { center_ids, couriers } from a body and checks every center exists
// and every courier is one Kubo works with.
const readChoices = async (body: Record<string, unknown>): Promise<Parsed<{ centerIds: number[]; couriers: Courier[] }>> => {
    const rawCenters: unknown = body.center_ids ?? [];
    const rawCouriers: unknown = body.couriers ?? [];
    if (!Array.isArray(rawCenters) || !Array.isArray(rawCouriers)) {
        return { error: 'center_ids and couriers must be lists', status: 400 };
    }
    const centerIds = [...new Set(rawCenters.map(Number))];
    if (!centerIds.every((id) => Number.isInteger(id) && id > 0)) {
        return { error: 'center_ids must be bagsakan center ids', status: 400 };
    }
    const known = new Set((await BagsakanModel.findAll()).map((center) => center.center_id));
    if (!centerIds.every((id) => known.has(id))) {
        return { error: 'One of the bagsakan centers was not found', status: 404 };
    }
    if (!rawCouriers.every(isCourier)) {
        return { error: 'One of the couriers is not one Kubo works with', status: 400 };
    }
    return { value: { centerIds, couriers: [...new Set(rawCouriers as Courier[])] } };
};

// GET /users/:id/fulfillment - public: the seller's profile choices.
export const getFulfillment = async (req: Request<{ id: string }>, res: Response): Promise<void> => {
    const sellerId = Number(req.params.id);
    if (!Number.isInteger(sellerId) || sellerId <= 0) {
        res.status(400).json({ success: false, message: 'Invalid user ID format' });
        return;
    }
    if (!(await UserModel.isActive(sellerId))) {
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    res.json({ success: true, data: await FulfillmentModel.forSeller(sellerId) });
};

// PUT /users/:id/fulfillment - behind requireAuth + requireOwner. Body:
// { center_ids: number[], couriers: string[] }. An empty list means the
// seller is not narrowing that one down. Listings with their own choices
// keep them.
export const updateFulfillment = async (req: Request<{ id: string }>, res: Response): Promise<void> => {
    const sellerId = Number(req.params.id);
    const choices = await readChoices(req.body ?? {});
    if (choices.error !== undefined) {
        res.status(choices.status).json({ success: false, message: choices.error });
        return;
    }
    await FulfillmentModel.save(sellerId, choices.value.centerIds, choices.value.couriers);
    res.json({ success: true, data: await FulfillmentModel.forSeller(sellerId) });
};

// GET /products/:id/fulfillment - public: what a buyer can pick on this
// listing. Its own choices when the seller set them, the profile's otherwise.
export const getProductFulfillment = async (req: Request<{ id: string }>, res: Response): Promise<void> => {
    const fulfillment = await FulfillmentModel.forProduct(Number(req.params.id));
    if (!fulfillment) {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return;
    }
    res.json({ success: true, data: fulfillment });
};

// PUT /products/:id/fulfillment - behind requireAuth; only the listing's
// seller. Body: { custom: boolean, center_ids, couriers }. custom false sends
// the listing back to following the profile. The profile is never changed.
export const updateProductFulfillment = async (req: Request<{ id: string }>, res: Response): Promise<void> => {
    const productId = Number(req.params.id);
    const product = await ProductModel.findById(productId);
    if (!product || product.status === 'delisted') {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return;
    }
    if (product.seller_id !== authUserId(res)) {
        res.status(403).json({ success: false, message: 'Only the seller can change this listing' });
        return;
    }
    const custom = req.body?.custom;
    if (typeof custom !== 'boolean') {
        res.status(400).json({ success: false, message: 'custom must be true or false' });
        return;
    }
    let centerIds: number[] = [];
    let couriers: Courier[] = [];
    if (custom) {
        const choices = await readChoices(req.body ?? {});
        if (choices.error !== undefined) {
            res.status(choices.status).json({ success: false, message: choices.error });
            return;
        }
        ({ centerIds, couriers } = choices.value);
    }
    await FulfillmentModel.saveForProduct(productId, custom, centerIds, couriers);
    res.json({ success: true, data: await FulfillmentModel.forProduct(productId) });
};

import { Request, Response } from "express";
import fs from "fs";
import path from "path";
import {
    farmingMethods,
    FarmingMethod,
    ProductChanges,
    ProductDetails,
    ProductListing,
    ProductModel,
    ProductStatus,
    productCategories,
    productUnits,
    qualityGrades,
    QualityGrade,
} from "#models/product.model";
import { authUserId } from "#middleware/auth.middleware";

const categories = new Set<string>(productCategories);
const units = new Set<string>(productUnits);
const grades = new Set<string>(qualityGrades);
const methods = new Set<string>(farmingMethods);
// Statuses a seller may set directly. 'delisted' only happens through DELETE.
const sellerStatuses = new Set<string>(['available', 'out of stock']);

export const maxListingImages = 10;
const maxDescriptionLength = 2000;
export const productUploadDirectory = path.resolve(__dirname, '../../uploads/products');
const uploadedImagePattern = /^\/uploads\/products\/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$/;

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

// Calendar date in the Philippines, where every seller and harvest is.
const todayInManila = (): string => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Manila' });

const isCalendarDate = (value: string): boolean => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const date = new Date(`${value}T00:00:00Z`);
    return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
};

// A photo is either one this server stored via POST /products/images, or
// an absolute URL (seed data).
const isAcceptedImage = (value: unknown): value is string => {
    if (typeof value !== 'string') return false;
    if (/^https?:\/\//.test(value)) return true;
    return uploadedImagePattern.test(value) && fs.existsSync(path.join(productUploadDirectory, path.basename(value)));
};

type Parsed<T> = { value: T; error?: undefined } | { value?: undefined; error: string };

const readImages = (images: unknown): Parsed<string[]> => {
    if (!Array.isArray(images) || images.length === 0) return { error: 'Add at least one photo' };
    if (images.length > maxListingImages) return { error: `A listing can have up to ${maxListingImages} photos` };
    if (!images.every(isAcceptedImage)) return { error: 'One of the photos was not uploaded. Please add it again.' };
    return { value: images };
};

// Reads the listing fields from a request body. On create every required
// field must be present; on update only the keys sent are checked.
const readDetails = (body: Record<string, unknown>, creating: boolean): Parsed<ProductChanges> => {
    const changes: ProductChanges = {};
    const has = (key: string) => body[key] !== undefined;

    if (creating || has('crop_name')) {
        const name = typeof body.crop_name === 'string' ? body.crop_name.trim() : '';
        if (!name) return { error: 'Enter a listing title' };
        if (name.length > 100) return { error: 'Listing title must be 100 characters or fewer' };
        changes.crop_name = name;
    }
    if (creating || has('category')) {
        if (typeof body.category !== 'string' || !categories.has(body.category)) return { error: 'Choose a category' };
        changes.category = body.category;
    }
    if (creating || has('unit_measurement')) {
        if (typeof body.unit_measurement !== 'string' || !units.has(body.unit_measurement)) return { error: 'Choose a unit' };
        changes.unit_measurement = body.unit_measurement;
    }
    if (creating || has('base_price')) {
        const price = Number(body.base_price);
        if (body.base_price === null || !Number.isFinite(price) || price <= 0) return { error: 'Enter a price above zero' };
        changes.base_price = price;
    }
    if (creating || has('available_quantity')) {
        const quantity = Number(body.available_quantity);
        // A live listing can be edited down to 0 stock; a new one cannot start there.
        if (body.available_quantity === null || !Number.isFinite(quantity) || quantity < 0 || (creating && quantity === 0)) {
            return { error: creating ? 'Enter how much you have to sell' : 'Available quantity cannot be negative' };
        }
        changes.available_quantity = quantity;
    }
    if (has('description')) {
        if (typeof body.description !== 'string') return { error: 'Description must be text' };
        if (body.description.length > maxDescriptionLength) return { error: `Description must be ${maxDescriptionLength} characters or fewer` };
        changes.description = body.description.trim();
    }
    if (has('quality_grade')) {
        if (typeof body.quality_grade !== 'string' || !grades.has(body.quality_grade)) return { error: 'Choose a quality grade' };
        changes.quality_grade = body.quality_grade as QualityGrade;
    }
    if (has('farming_method')) {
        if (typeof body.farming_method !== 'string' || !methods.has(body.farming_method)) return { error: 'Choose a farming method' };
        changes.farming_method = body.farming_method as FarmingMethod;
    }
    if (has('harvest_date')) {
        if (body.harvest_date !== null && (typeof body.harvest_date !== 'string' || !isCalendarDate(body.harvest_date))) {
            return { error: 'Harvest date must be a valid date' };
        }
        changes.harvest_date = body.harvest_date as string | null;
    }
    for (const key of ['is_preorder', 'allows_meetup', 'allows_delivery'] as const) {
        if (!has(key)) continue;
        if (typeof body[key] !== 'boolean') return { error: `${key} must be true or false` };
        changes[key] = body[key] as boolean;
    }
    return { value: changes };
};

// Rules that span fields, checked against the listing as it will be saved.
// Harvest dates are only compared with today when they differ from what is
// stored (always, on create), so a pre-order whose harvest day has passed
// can still be edited; the app resends every field on each save.
type RuleFields = Partial<Pick<ProductDetails, 'harvest_date' | 'is_preorder' | 'allows_meetup' | 'allows_delivery'>>;

const checkListingRules = (listing: RuleFields, previous?: RuleFields): string | undefined => {
    if (!listing.allows_meetup && !listing.allows_delivery) return 'Please choose a deal method';
    if (listing.is_preorder && !listing.harvest_date) return 'Pre-orders need an expected harvest date';
    const harvestChanged = !previous
        || listing.harvest_date !== previous.harvest_date
        || listing.is_preorder !== previous.is_preorder;
    if (harvestChanged && listing.harvest_date) {
        const today = todayInManila();
        if (listing.is_preorder && listing.harvest_date < today) return 'Expected harvest date cannot be in the past';
        if (!listing.is_preorder && listing.harvest_date > today) {
            return 'Harvest date is in the future. Turn on pre-order to list a crop before harvest.';
        }
    }
    return undefined;
};

// Removes uploaded photos that no listing uses any more.
const deleteUnusedUploads = (images: string[]): void => {
    for (const image of images) {
        if (!uploadedImagePattern.test(image) || ProductModel.isImageInUse(image)) continue;
        const file = path.join(productUploadDirectory, path.basename(image));
        fs.rm(file, { force: true }, (error) => {
            if (error) console.error(`Could not delete unused listing photo ${file}:`, error);
        });
    }
};

export const getProducts = (req: Request, res: Response): void => {
    const query = typeof req.query.q === 'string' ? req.query.q : '';
    const sellerId = typeof req.query.seller_id === 'string' ? Number(req.query.seller_id) : undefined;
    // A seller's own tab asks for sold-out rows too; public views never do.
    const includeUnavailable = req.query.include_unavailable === 'true';
    res.json({ success: true, data: ProductModel.findAll(query, Number.isInteger(sellerId) ? sellerId : undefined, includeUnavailable) });
};

export const getProduct = (req: Request, res: Response): void => {
    const product = ProductModel.findById(Number(req.params.id));
    if (!product) {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return;
    }
    res.json({ success: true, data: product });
};

// Stores the photos for a listing that is about to be created or edited and
// returns their paths, in upload order, for the images field.
export const uploadProductImages = (req: Request, res: Response): void => {
    const files = Array.isArray(req.files) ? req.files : [];
    if (files.length === 0) {
        res.status(400).json({ success: false, message: 'Add a JPG, PNG, or WebP photo' });
        return;
    }
    res.status(201).json({ success: true, data: { images: files.map((file) => `/uploads/products/${file.filename}`) } });
};

export const createProduct = (req: Request, res: Response): void => {
    // The seller is whoever is signed in; a seller_id in the body is ignored.
    const seller_id = authUserId(res);
    const details = readDetails(req.body ?? {}, true);
    if (details.error !== undefined) {
        res.status(400).json({ success: false, message: details.error });
        return;
    }
    const images = readImages(req.body?.images);
    if (images.error !== undefined) {
        res.status(400).json({ success: false, message: images.error });
        return;
    }
    // readDetails has already required every field without a default here.
    const listing = {
        description: '',
        quality_grade: 'standard',
        farming_method: 'conventional',
        harvest_date: null,
        is_preorder: false,
        allows_meetup: true,
        allows_delivery: true,
        ...details.value,
    } as ProductDetails;
    const ruleError = checkListingRules(listing);
    if (ruleError) {
        res.status(400).json({ success: false, message: ruleError });
        return;
    }
    try {
        const product = ProductModel.create({ ...listing, seller_id }, images.value);
        res.status(201).json({ success: true, data: product });
    } catch (error) {
        res.status(400).json({ success: false, message: error instanceof Error ? error.message : 'Unable to create listing' });
    }
};

// Loads the listing and checks the signed-in user is its seller.
const loadOwnedProduct = (req: Request, res: Response): ProductListing | undefined => {
    const productId = readId(req.params.id);
    const sellerId = authUserId(res);
    if (!productId) {
        res.status(400).json({ success: false, message: 'Invalid listing id' });
        return undefined;
    }
    const product = ProductModel.findById(productId);
    if (!product || product.status === 'delisted') {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return undefined;
    }
    if (product.seller_id !== sellerId) {
        res.status(403).json({ success: false, message: 'Only the seller can change this listing' });
        return undefined;
    }
    return product;
};

// Seller edits the listing details and/or marks it sold out or available.
export const updateProduct = (req: Request, res: Response): void => {
    const product = loadOwnedProduct(req, res);
    if (!product) return;

    const body = req.body ?? {};
    const details = readDetails(body, false);
    if (details.error !== undefined) {
        res.status(400).json({ success: false, message: details.error });
        return;
    }
    const changes = details.value;
    if (body.status !== undefined) {
        if (!sellerStatuses.has(body.status)) {
            res.status(400).json({ success: false, message: `status must be one of: ${[...sellerStatuses].join(', ')}` });
            return;
        }
        changes.status = body.status as ProductStatus;
    }
    let images: string[] | undefined;
    if (body.images !== undefined) {
        const parsed = readImages(body.images);
        if (parsed.error !== undefined) {
            res.status(400).json({ success: false, message: parsed.error });
            return;
        }
        images = parsed.value;
    }
    const ruleError = checkListingRules({ ...product, ...changes }, product);
    if (ruleError) {
        res.status(400).json({ success: false, message: ruleError });
        return;
    }

    try {
        const updated = ProductModel.update(product.product_id, changes, images);
        if (images) deleteUnusedUploads(product.images.filter((image) => !images.includes(image)));
        res.json({ success: true, data: updated });
    } catch (error) {
        res.status(400).json({ success: false, message: error instanceof Error ? error.message : 'Unable to update listing' });
    }
};

// Soft delete. The row stays so buyers' past offers on it keep resolving;
// it just never appears in any list again.
export const deleteProduct = (req: Request, res: Response): void => {
    const product = loadOwnedProduct(req, res);
    if (!product) return;
    ProductModel.update(product.product_id, { status: 'delisted' });
    res.json({ success: true, data: { product_id: product.product_id, status: 'delisted' } });
};

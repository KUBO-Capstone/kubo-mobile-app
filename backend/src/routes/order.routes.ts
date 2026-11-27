import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { receiveImages } from "#controllers/upload.controller";
import {
    createOrder,
    getOrder,
    getOrders,
    requireShippableOrder,
    updateOrder,
    uploadHandoverPhotos,
} from "#controllers/order.controller";
import { createReview, requireReviewableOrder, uploadReviewPhotos } from "#controllers/review.controller";
import { maxReviewPhotos } from "#models/review.model";
import { maxHandoverPhotos } from "#models/order.model";

const receiveReviewPhotos = receiveImages({
    field: 'photos',
    folder: 'reviews',
    maxFiles: maxReviewPhotos,
    maxBytes: 8 * 1024 * 1024,
    // Short clips of the produce, up to 10 MB each.
    maxVideoBytes: 10 * 1024 * 1024,
    messages: {
        LIMIT_FILE_SIZE: 'Photos must be 8 MB or smaller, and videos 10 MB',
        LIMIT_FILE_COUNT: `A review can have up to ${maxReviewPhotos} photos and videos`,
        LIMIT_UNEXPECTED_FILE: `A review can have up to ${maxReviewPhotos} photos and videos`,
    },
});

const receiveHandoverPhotos = receiveImages({
    field: 'photos',
    folder: 'handovers',
    maxFiles: maxHandoverPhotos,
    maxBytes: 8 * 1024 * 1024,
    messages: {
        LIMIT_FILE_SIZE: 'Each photo must be 8 MB or smaller',
        LIMIT_FILE_COUNT: `An order can have up to ${maxHandoverPhotos} handover photos`,
        LIMIT_UNEXPECTED_FILE: `An order can have up to ${maxHandoverPhotos} handover photos`,
    },
});

const router = Router();
// Every route here acts as, or reads for, the signed-in user.
router.use(requireAuth);
router.get('/', getOrders);
router.get('/:id', getOrder);
router.post('/', createOrder);
router.patch('/:id', updateOrder);
router.post('/:id/handover/photos', requireShippableOrder, receiveHandoverPhotos, uploadHandoverPhotos);
router.post('/:id/review/photos', requireReviewableOrder, receiveReviewPhotos, uploadReviewPhotos);
router.post('/:id/review', createReview);

export default router;

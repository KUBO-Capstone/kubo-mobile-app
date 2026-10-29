import { Request, Response } from "express";
import { OrderModel } from "#models/order.model";
import { buyerReviewTags, ReviewModel, sellerReviewTags } from "#models/review.model";
import { NotificationModel } from "#models/notification.model";
import { UserModel } from "#models/user.model";
import { authUserId } from "#middleware/auth.middleware";

const maxCommentLength = 1000;
const sellerTags = new Set<string>(sellerReviewTags);
const buyerTags = new Set<string>(buyerReviewTags);

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

// POST /orders/:id/review - either party rates the other once the order is
// delivered. Mounted behind requireAuth with the other order routes.
export const createReview = (req: Request, res: Response): void => {
    const reviewerId = authUserId(res);
    const orderId = readId(req.params.id);
    if (!orderId) {
        res.status(400).json({ success: false, message: 'Invalid order id' });
        return;
    }
    const rating = Number(req.body?.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
        res.status(400).json({ success: false, message: 'Choose a rating from 1 to 5 stars' });
        return;
    }
    const comment = typeof req.body?.comment === 'string' ? req.body.comment.trim() : '';
    if (comment.length > maxCommentLength) {
        res.status(400).json({ success: false, message: `Reviews must be ${maxCommentLength} characters or fewer` });
        return;
    }

    const order = OrderModel.findById(orderId);
    if (!order) {
        res.status(404).json({ success: false, message: 'Order not found' });
        return;
    }
    const isBuyer = order.buyer_id === reviewerId;
    if (!isBuyer && order.seller_id !== reviewerId) {
        res.status(403).json({ success: false, message: 'You are not part of this order' });
        return;
    }
    if (order.order_status !== 'delivered') {
        res.status(409).json({ success: false, message: 'You can leave a review once the order has been received' });
        return;
    }

    // A buyer describes the seller and the produce; a seller describes the buyer.
    const allowedTags = isBuyer ? sellerTags : buyerTags;
    const rawTags: unknown[] = req.body?.tags === undefined ? [] : Array.isArray(req.body.tags) ? req.body.tags : [null];
    if (!rawTags.every((tag): tag is string => typeof tag === 'string' && allowedTags.has(tag))) {
        res.status(400).json({ success: false, message: 'One of the tags is not available for this review' });
        return;
    }
    const tags = [...new Set(rawTags as string[])];

    if (ReviewModel.findByOrderAndReviewer(orderId, reviewerId)) {
        res.status(409).json({ success: false, message: 'You already reviewed this order' });
        return;
    }

    const revieweeId = isBuyer ? order.seller_id : order.buyer_id;
    let review;
    try {
        review = ReviewModel.create({ order_id: orderId, reviewer_id: reviewerId, reviewee_id: revieweeId, rating, comment, tags });
    } catch (error) {
        // Two taps racing past the check above hit the unique index instead.
        if (error instanceof Error && error.message.includes('UNIQUE')) {
            res.status(409).json({ success: false, message: 'You already reviewed this order' });
            return;
        }
        throw error;
    }

    const snippet = comment.length > 80 ? `${comment.slice(0, 77)}...` : comment;
    NotificationModel.create({
        recipientId: revieweeId,
        senderId: reviewerId,
        productId: order.product_id,
        title: 'New Review',
        message: `${review.reviewer_name} rated you ${rating} star${rating === 1 ? '' : 's'}${snippet ? `: "${snippet}"` : ''}`,
    });
    res.status(201).json({ success: true, data: review });
};

// GET /users/:id/reviews - public, like the profile it sits on.
export const getUserReviews = (req: Request, res: Response): void => {
    const userId = readId(req.params.id);
    if (!userId) {
        res.status(400).json({ success: false, message: 'Invalid user ID format' });
        return;
    }
    if (!UserModel.findById(userId)) {
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    res.json({ success: true, data: { summary: ReviewModel.summaryFor(userId), reviews: ReviewModel.findForUser(userId) } });
};

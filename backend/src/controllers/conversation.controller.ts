import { Request, Response } from "express";
import { ConversationModel, ConversationSummary } from "#models/conversation.model";
import { ProductModel } from "#models/product.model";

// KNOWN DEBT: same identity stopgap as negotiations - `user_id` / `sender_id`
// / `buyer_id` come from the request and are trusted until Phase 2 auth.

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

// Loads the thread and checks the caller is one of its two parties.
const loadOwnConversation = (req: Request, res: Response, userId: number | undefined): ConversationSummary | undefined => {
    const conversationId = readId(req.params.id);
    if (!conversationId || !userId) {
        res.status(400).json({ success: false, message: 'user_id is required' });
        return undefined;
    }
    const conversation = ConversationModel.findById(conversationId, userId);
    if (!conversation) {
        res.status(404).json({ success: false, message: 'Conversation not found' });
        return undefined;
    }
    if (conversation.buyer_id !== userId && conversation.seller_id !== userId) {
        res.status(403).json({ success: false, message: 'You are not part of this conversation' });
        return undefined;
    }
    return conversation;
};

// Inbox for the signed-in user.
export const getConversations = (req: Request, res: Response): void => {
    const userId = readId(req.query.user_id);
    if (!userId) {
        res.status(400).json({ success: false, message: 'user_id is required' });
        return;
    }
    res.json({ success: true, data: ConversationModel.findForUser(userId) });
};

// Thread header data (product, parties, current offer) for the chat screen.
export const getConversation = (req: Request, res: Response): void => {
    const conversation = loadOwnConversation(req, res, readId(req.query.user_id));
    if (!conversation) return;
    res.json({ success: true, data: conversation });
};

// Buyer opens (or reopens) a thread on a listing without making an offer -
// the Message button. Sellers never start threads: a listing's thread is
// always keyed by the buyer who reached out.
export const createConversation = (req: Request, res: Response): void => {
    const buyerId = readId(req.body.buyer_id);
    const productId = readId(req.body.product_id);
    if (!buyerId || !productId) {
        res.status(400).json({ success: false, message: 'buyer_id and product_id are required' });
        return;
    }
    const product = ProductModel.findById(productId);
    if (!product || product.status === 'delisted') {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return;
    }
    if (product.seller_id === buyerId) {
        res.status(400).json({ success: false, message: 'You cannot message yourself about your own listing' });
        return;
    }
    const conversationId = ConversationModel.findOrCreate(buyerId, product.seller_id, productId);
    res.status(201).json({ success: true, data: ConversationModel.findById(conversationId, buyerId) });
};

export const getMessages = (req: Request, res: Response): void => {
    const conversation = loadOwnConversation(req, res, readId(req.query.user_id));
    if (!conversation) return;
    res.json({ success: true, data: ConversationModel.messages(conversation.conversation_id) });
};

export const sendMessage = (req: Request, res: Response): void => {
    const senderId = readId(req.body.sender_id);
    const conversation = loadOwnConversation(req, res, senderId);
    if (!conversation) return;
    const content = typeof req.body.content === 'string' ? req.body.content.trim() : '';
    if (!content) {
        res.status(400).json({ success: false, message: 'content cannot be empty' });
        return;
    }
    if (content.length > 2000) {
        res.status(400).json({ success: false, message: 'Messages are limited to 2000 characters' });
        return;
    }
    const message = ConversationModel.addMessage({
        conversation_id: conversation.conversation_id,
        sender_id: senderId!,
        content,
    });
    res.status(201).json({ success: true, data: message });
};

// Clears the unread dot for the caller.
export const markConversationRead = (req: Request, res: Response): void => {
    const userId = readId(req.body.user_id);
    const conversation = loadOwnConversation(req, res, userId);
    if (!conversation) return;
    const updated = ConversationModel.markRead(conversation.conversation_id, userId!);
    res.json({ success: true, data: { conversation_id: conversation.conversation_id, marked_read: updated } });
};

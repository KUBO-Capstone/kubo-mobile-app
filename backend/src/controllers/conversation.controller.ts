import { Request, Response } from "express";
import { ConversationModel, ConversationSummary } from "#models/conversation.model";
import { ProductModel } from "#models/product.model";
import { authUserId } from "#middleware/auth.middleware";
import { isMessageId } from "#models/message.model";
import { listChatMessages, sendChatMessage } from "#services/chat.service";

// Mounted behind requireAuth: the caller is always authUserId(res).

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

// Loads the thread and checks the caller is one of its two parties.
const loadOwnConversation = (req: Request, res: Response): ConversationSummary | undefined => {
    const userId = authUserId(res);
    const conversationId = readId(req.params.id);
    if (!conversationId) {
        res.status(400).json({ success: false, message: 'Invalid conversation id' });
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
    res.json({ success: true, data: ConversationModel.findForUser(authUserId(res)) });
};

// Thread header data (product, parties, current offer) for the chat screen.
export const getConversation = (req: Request, res: Response): void => {
    const conversation = loadOwnConversation(req, res);
    if (!conversation) return;
    res.json({ success: true, data: conversation });
};

// Buyer opens (or reopens) a thread on a listing without making an offer -
// the Message button. Sellers never start threads: a listing's thread is
// always keyed by the buyer who reached out.
export const createConversation = (req: Request, res: Response): void => {
    const buyerId = authUserId(res);
    const productId = readId(req.body.product_id);
    if (!productId) {
        res.status(400).json({ success: false, message: 'product_id is required' });
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

// ?after=<message_id> returns only newer messages; the app uses it to catch
// up on whatever it missed while its socket was disconnected.
export const getMessages = async (req: Request, res: Response): Promise<void> => {
    const conversation = loadOwnConversation(req, res);
    if (!conversation) return;
    const after = req.query.after;
    if (after !== undefined && (typeof after !== 'string' || !isMessageId(after))) {
        res.status(400).json({ success: false, message: 'after must be a message id' });
        return;
    }
    res.json({ success: true, data: await listChatMessages(conversation.conversation_id, after) });
};

export const sendMessage = async (req: Request, res: Response): Promise<void> => {
    const conversation = loadOwnConversation(req, res);
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
    const message = await sendChatMessage({
        conversation_id: conversation.conversation_id,
        sender_id: authUserId(res),
        content,
    });
    res.status(201).json({ success: true, data: message });
};

// Clears the unread dot for the caller.
export const markConversationRead = (req: Request, res: Response): void => {
    const conversation = loadOwnConversation(req, res);
    if (!conversation) return;
    const updated = ConversationModel.markRead(conversation.conversation_id, authUserId(res));
    res.json({ success: true, data: { conversation_id: conversation.conversation_id, marked_read: updated } });
};

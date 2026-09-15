import { Router } from "express";
import {
    createConversation,
    getConversation,
    getConversations,
    getMessages,
    markConversationRead,
    sendMessage,
} from "#controllers/conversation.controller";

const router = Router();
router.get('/', getConversations);
router.post('/', createConversation);
router.get('/:id', getConversation);
router.get('/:id/messages', getMessages);
router.post('/:id/messages', sendMessage);
router.patch('/:id/read', markConversationRead);

export default router;

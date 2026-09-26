import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import {
    createConversation,
    getConversation,
    getConversations,
    getMessages,
    markConversationRead,
    sendMessage,
} from "#controllers/conversation.controller";

const router = Router();
// Every route here acts as, or reads for, the signed-in user.
router.use(requireAuth);
router.get('/', getConversations);
router.post('/', createConversation);
router.get('/:id', getConversation);
router.get('/:id/messages', getMessages);
router.post('/:id/messages', sendMessage);
router.patch('/:id/read', markConversationRead);

export default router;

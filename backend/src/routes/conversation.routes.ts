import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import {
    createConversation,
    getConversation,
    getConversations,
    getMessages,
    markConversationRead,
    requireOwnConversation,
    sendMessage,
    uploadChatPhoto,
} from "#controllers/conversation.controller";
import { receiveImages } from "#controllers/upload.controller";

// One photo or video per media message; videos up to 10 MB.
const receiveChatPhoto = receiveImages({
    field: 'photos',
    folder: 'chats',
    maxFiles: 1,
    maxBytes: 8 * 1024 * 1024,
    maxVideoBytes: 10 * 1024 * 1024,
    messages: {
        LIMIT_FILE_SIZE: 'Photos must be 8 MB or smaller, and videos 10 MB',
        LIMIT_FILE_COUNT: 'Send one photo or video at a time',
        LIMIT_UNEXPECTED_FILE: 'Send one photo or video at a time',
    },
});

const router = Router();
// Every route here acts as, or reads for, the signed-in user.
router.use(requireAuth);
router.get('/', getConversations);
router.post('/', createConversation);
router.get('/:id', getConversation);
router.get('/:id/messages', getMessages);
router.post('/:id/messages', sendMessage);
router.post('/:id/photos', requireOwnConversation, receiveChatPhoto, uploadChatPhoto);
router.patch('/:id/read', markConversationRead);

export default router;

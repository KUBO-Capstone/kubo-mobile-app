import { ConversationModel } from "#models/conversation.model";
import { MessageModel, NewMessage, StoredMessage } from "#models/message.model";
import { NotificationModel } from "#models/notification.model";
import { UserModel } from "#models/user.model";
import { emitToUsers } from "#services/socket.service";
import { belongsToThread, ThreadBounds } from "#services/chat-thread-filter";

/** A message as the API returns it: the DynamoDB item plus the sender's name. */
export type ChatMessage = StoredMessage & { sender_name: string };

// Names are looked up at read time rather than copied into DynamoDB, so an
// anonymized sender shows as "Deleted User" everywhere at once.
async function withSenderNames(messages: StoredMessage[]): Promise<ChatMessage[]> {
    const names = new Map<number, string>();
    await Promise.all([...new Set(messages.map((m) => m.sender_id))].map(async (id) => {
        const user = await UserModel.findById(id);
        names.set(id, user ? `${user.first_name} ${user.last_name}` : 'Deleted User');
    }));
    return messages.map((m) => ({ ...m, sender_name: names.get(m.sender_id) ?? 'Deleted User' }));
}

function notificationTitle(message: StoredMessage): string {
    if (message.message_type === 'offer' || message.message_type === 'counter') return 'New Offer';
    if (message.message_type === 'order'
        && (message.content.startsWith('Received order #') || message.content.startsWith('Picked up order #'))) {
        return 'Delivered';
    }
    return 'New Message';
}

// The one way a message enters a thread: typed text, offer events and order
// events all go through here. The message is saved to DynamoDB first, then
// the inbox preview and the recipient's notification are updated, then the
// message is pushed as `message:new` to both parties - including the
// sender's own room, so their other devices stay in sync. If nobody is
// connected the push is simply lost; clients catch up with
// GET /conversations/:id/messages?after=<message_id>.
export async function sendChatMessage(input: NewMessage): Promise<ChatMessage> {
    const parties = await ConversationModel.parties(input.conversation_id);
    if (!parties) throw new Error(`Conversation ${input.conversation_id} does not exist`);

    const stored = await MessageModel.create(input);
    await ConversationModel.recordLastMessage(input.conversation_id, stored);

    const recipientId = parties.buyer_id === input.sender_id ? parties.seller_id : parties.buyer_id;

    try {
        await NotificationModel.create({
            recipientId,
            senderId: input.sender_id,
            productId: parties.product_id,
            title: notificationTitle(stored),
            message: stored.content,
        });
    } catch (error) {
        console.error('Failed to create chat notification', error);
    }

    const [message] = await withSenderNames([stored]);
    emitToUsers([parties.buyer_id, parties.seller_id], 'message:new', message);
    return message;
}

// Leftovers stored under a reused conversation_id are left out; see
// chat-thread-filter.ts.
export async function listChatMessages(
    thread: ThreadBounds & { conversation_id: number },
    afterId?: string,
): Promise<ChatMessage[]> {
    const stored = await MessageModel.listForConversation(thread.conversation_id, afterId);
    return withSenderNames(stored.filter((message) => belongsToThread(message, thread)));
}

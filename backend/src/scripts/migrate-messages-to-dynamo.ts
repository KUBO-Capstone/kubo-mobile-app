/**
 * One-time copy of the legacy SQLite `messages` table into DynamoDB, plus a
 * backfill of the conversation preview and read-cursor columns.
 *
 * Re-runnable: a conversation that already has messages in DynamoDB is
 * skipped, so a partial run can simply be started again.
 * Run:  npm run migrate:messages
 */
import 'dotenv/config'; // must stay first so env vars exist before other imports read them
import { monotonicFactory } from 'ulid';
import { db } from '#config/database';
import { ConversationModel } from '#models/conversation.model';
import { MessageModel, MessageType } from '#models/message.model';

interface LegacyMessage {
    message_id: number;
    conversation_id: number;
    sender_id: number;
    content: string;
    message_type: MessageType;
    negotiation_id: number | null;
    order_id: number | null;
    offer_price: number | null;
    offer_quantity: number | null;
    read_at: string | null;
    sent_at: string;
}

// SQLite CURRENT_TIMESTAMP is UTC 'YYYY-MM-DD HH:MM:SS'.
const parseSqliteTime = (value: string): Date => new Date(`${value.replace(' ', 'T')}Z`);
const orUndefined = <T>(value: T | null): T | undefined => (value === null ? undefined : value);

async function main(): Promise<void> {
    const conversations = db.prepare(`
        SELECT DISTINCT m.conversation_id, c.buyer_id, c.seller_id
        FROM messages m JOIN conversations c ON c.conversation_id = m.conversation_id
        ORDER BY m.conversation_id
    `).all() as { conversation_id: number; buyer_id: number; seller_id: number }[];

    let copied = 0;
    let skipped = 0;
    for (const conversation of conversations) {
        const id = conversation.conversation_id;
        if ((await MessageModel.listForConversation(id)).length > 0) {
            console.log(`conversation ${id}: already in DynamoDB, skipped`);
            skipped++;
            continue;
        }

        const rows = db.prepare('SELECT * FROM messages WHERE conversation_id = ? ORDER BY message_id')
            .all(id) as LegacyMessage[];
        // A fresh factory per thread keeps each id's time equal to its own
        // sent_at; rows from the same second still sort in their old order.
        const nextId = monotonicFactory();
        let last;
        for (const row of rows) {
            const sentAt = parseSqliteTime(row.sent_at);
            last = await MessageModel.create({
                conversation_id: id,
                sender_id: row.sender_id,
                content: row.content,
                message_type: row.message_type,
                negotiation_id: orUndefined(row.negotiation_id),
                order_id: orUndefined(row.order_id),
                offer_price: orUndefined(row.offer_price),
                offer_quantity: orUndefined(row.offer_quantity),
            }, { sentAt, messageId: nextId(sentAt.getTime()) });
        }
        if (last) ConversationModel.recordLastMessage(id, last);

        // Old rows tracked reads per message; the new model keeps one cursor
        // per party. A party has read up to the newest message they marked read.
        const readUpTo = (readerId: number): string | null => {
            const newest = [...rows].reverse().find((r) => r.sender_id !== readerId && r.read_at !== null);
            return newest ? parseSqliteTime(newest.sent_at).toISOString() : null;
        };
        db.prepare('UPDATE conversations SET buyer_last_read_at = ?, seller_last_read_at = ? WHERE conversation_id = ?')
            .run(readUpTo(conversation.buyer_id), readUpTo(conversation.seller_id), id);

        console.log(`conversation ${id}: copied ${rows.length} messages`);
        copied += rows.length;
    }
    console.log(`Done: ${copied} messages copied, ${skipped} conversations skipped.`);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});

/**
 * One-time copy of the legacy SQLite `messages` table into DynamoDB, plus a
 * backfill of the conversation preview and read-cursor columns.
 *
 * Re-runnable: each message id is derived from its old row, so rows already
 * copied are left as they are and a partial run can simply be started again.
 * Run:  npm run migrate:messages
+* Before this command, stop every old server that can write SQLite messages.
+* Run `npm run ddb:create-messages` first, then `npm run migrate:messages`.
 */
import 'dotenv/config'; // must stay first so env vars exist before other imports read them
import { encodeTime, TIME_LEN } from 'ulid';
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

// A ULID whose time part is the row's sent_at and whose random part is the
// zero-padded old message_id: the same row always gets the same id, and rows
// from the same second still sort in their old order.
const legacyMessageId = (row: LegacyMessage, sentAt: Date): string =>
    encodeTime(sentAt.getTime(), TIME_LEN) + String(row.message_id).padStart(16, '0');

const isAlreadyCopied = (err: unknown): boolean =>
    err instanceof Error && err.name === 'ConditionalCheckFailedException';

async function main(): Promise<void> {
    const conversations = db.prepare(`
        SELECT DISTINCT m.conversation_id, c.buyer_id, c.seller_id
        FROM messages m JOIN conversations c ON c.conversation_id = m.conversation_id
        ORDER BY m.conversation_id
    `).all() as { conversation_id: number; buyer_id: number; seller_id: number }[];

    let copied = 0;
    let existing = 0;
    for (const conversation of conversations) {
        const id = conversation.conversation_id;
        const rows = db.prepare('SELECT * FROM messages WHERE conversation_id = ? ORDER BY message_id')
            .all(id) as LegacyMessage[];
        let copiedHere = 0;
        for (const row of rows) {
            const sentAt = parseSqliteTime(row.sent_at);
            try {
                await MessageModel.create({
                    conversation_id: id,
                    sender_id: row.sender_id,
                    content: row.content,
                    message_type: row.message_type,
                    negotiation_id: orUndefined(row.negotiation_id),
                    order_id: orUndefined(row.order_id),
                    offer_price: orUndefined(row.offer_price),
                    offer_quantity: orUndefined(row.offer_quantity),
                }, { sentAt, messageId: legacyMessageId(row, sentAt) });
                copiedHere++;
            } catch (err) {
                if (!isAlreadyCopied(err)) throw err;
            }
        }
        // Only ever moves the preview forward, so a rerun is harmless.
        const last = rows[rows.length - 1];
        if (last) {
            ConversationModel.recordLastMessage(id, {
                sender_id: last.sender_id,
                content: last.content,
                sent_at: parseSqliteTime(last.sent_at).toISOString(),
            });
        }

        // Old rows tracked reads per message; the new model keeps one cursor
        // per party. A party has read up to the newest message they marked read.
        // Cursors only move forward, so a rerun never unreads what was read since.
        const readUpTo = (readerId: number): string | null => {
            const newest = [...rows].reverse().find((r) => r.sender_id !== readerId && r.read_at !== null);
            return newest ? parseSqliteTime(newest.sent_at).toISOString() : null;
        };
        db.prepare(`
            UPDATE conversations
            SET buyer_last_read_at  = CASE WHEN @buyer  > COALESCE(buyer_last_read_at, '')  THEN @buyer  ELSE buyer_last_read_at END,
                seller_last_read_at = CASE WHEN @seller > COALESCE(seller_last_read_at, '') THEN @seller ELSE seller_last_read_at END
            WHERE conversation_id = @id
        `).run({ buyer: readUpTo(conversation.buyer_id), seller: readUpTo(conversation.seller_id), id });

        console.log(`conversation ${id}: copied ${copiedHere} of ${rows.length} messages`);
        copied += copiedHere;
        existing += rows.length - copiedHere;
    }
    console.log(`Done: ${copied} messages copied, ${existing} already in DynamoDB.`);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});

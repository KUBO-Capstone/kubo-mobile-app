import { PutCommand, QueryCommand, QueryCommandInput } from "@aws-sdk/lib-dynamodb";
import { isValid, monotonicFactory } from "ulid";
import { ddb } from "#config/aws";

// Chat messages live in the DynamoDB table ChatMessages, not SQLite/RDS:
//   PK chatRoomId (S) = String(conversation_id) - one partition per thread
//   SK timestamp  (S) = message_id, a ULID: its leading characters encode
//                       the send time, so sort order is send order and
//                       "after <id>" is a plain range condition
// The API keeps speaking conversation_id / message_id; toItem/fromItem are
// the only places that know the table's key names. Conversation metadata
// (parties, inbox preview, read cursors) stays in the relational database;
// see conversations in database/migrations/001_init.sql.

// 'text' is a chat line; the rest are offer events written by the negotiation
// controller so the thread doubles as the offer history (a counter overwrites
// the price on the negotiations row, the messages keep every step). 'order'
// is written by the order controller for placed / shipped / delivered /
// cancelled, with `order_id` pointing at the order.
export type MessageType = 'text' | 'offer' | 'counter' | 'accepted' | 'declined' | 'order';

/** A message as stored in DynamoDB. */
export interface StoredMessage {
    conversation_id: number;
    message_id: string;
    sender_id: number;
    content: string;
    message_type: MessageType;
    negotiation_id?: number;
    order_id?: number;
    offer_price?: number;
    offer_quantity?: number;
    sent_at: string;            // ISO 8601, UTC
}

export type NewMessage = Omit<StoredMessage, 'message_id' | 'sent_at' | 'message_type'> & {
    message_type?: MessageType;
};

// Read lazily: dotenv may not have run yet when this module is imported.
const table = (): string => process.env.DDB_MESSAGES_TABLE ?? 'ChatMessages';

// `timestamp` is a DynamoDB reserved word, so expressions use #ts.
const KEY_NAMES = { '#ts': 'timestamp' };

type Item = Omit<StoredMessage, 'conversation_id' | 'message_id'> & { chatRoomId: string; timestamp: string };

const toItem = ({ conversation_id, message_id, ...rest }: StoredMessage): Item =>
    ({ ...rest, chatRoomId: String(conversation_id), timestamp: message_id });

const fromItem = ({ chatRoomId, timestamp, ...rest }: Item): StoredMessage =>
    ({ ...rest, conversation_id: Number(chatRoomId), message_id: timestamp });

// Monotonic so two messages in the same millisecond still sort in send order.
const nextId = monotonicFactory();

export const isMessageId = (value: string): boolean => isValid(value);

export const MessageModel = {
    /**
     * @param backfill only for copying old messages in with their original
     *   time and an id generated from it; new messages use the current time.
     */
    async create(input: NewMessage, backfill?: { sentAt: Date; messageId: string }): Promise<StoredMessage> {
        const sentAt = backfill?.sentAt ?? new Date();
        const item: StoredMessage = {
            ...input,
            message_type: input.message_type ?? 'text',
            message_id: backfill?.messageId ?? nextId(sentAt.getTime()),
            sent_at: sentAt.toISOString(),
        };
        await ddb.send(new PutCommand({
            TableName: table(),
            Item: toItem(item),
            ConditionExpression: 'attribute_not_exists(#ts)',
            ExpressionAttributeNames: KEY_NAMES,
        }));
        return item;
    },

    /** The thread oldest first, or only the messages after `afterId`. */
    async listForConversation(conversationId: number, afterId?: string): Promise<StoredMessage[]> {
        const input: QueryCommandInput = {
            TableName: table(),
            KeyConditionExpression: afterId ? 'chatRoomId = :c AND #ts > :after' : 'chatRoomId = :c',
            ...(afterId ? { ExpressionAttributeNames: KEY_NAMES } : {}),
            ExpressionAttributeValues: afterId
                ? { ':c': String(conversationId), ':after': afterId }
                : { ':c': String(conversationId) },
            ScanIndexForward: true,
        };
        const items: StoredMessage[] = [];
        do {
            const page = await ddb.send(new QueryCommand(input));
            items.push(...((page.Items ?? []) as Item[]).map(fromItem));
            input.ExclusiveStartKey = page.LastEvaluatedKey;
        } while (input.ExclusiveStartKey);
        return items;
    },
};

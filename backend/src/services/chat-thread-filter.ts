// DynamoDB keeps each thread's messages under its conversation_id. Those ids
// have been reused once already: the conversations table started counting
// from 1 again while the messages of the old threads stayed in DynamoDB, so
// a brand-new conversation opened showing two other people's chat and
// offers. Only messages that can belong to a thread are handed out: sent by
// one of its two people, and not from before the thread existed.

/** What decides whether a stored message belongs to a thread. */
export interface ThreadBounds {
    buyer_id: number;
    seller_id: number;
    /** When the conversation row was created (any Date-parsable string). */
    created_at: string;
}

/** The sender and time of a stored message. */
export interface ThreadMessage {
    sender_id: number;
    sent_at: string;
}

// sent_at comes from the app server's clock and created_at from the
// database's; this covers one running a little behind the other, so a first
// message sent right after the thread is opened is never lost. Leftovers
// from a reused id are weeks older.
export const CLOCK_SKEW_MS = 5 * 60_000;

export function belongsToThread(message: ThreadMessage, thread: ThreadBounds): boolean {
    const sender = Number(message.sender_id);
    if (sender !== Number(thread.buyer_id) && sender !== Number(thread.seller_id)) return false;
    const opened = new Date(thread.created_at).getTime();
    const sent = new Date(message.sent_at).getTime();
    // An unreadable date proves nothing either way; the sender check stands.
    if (Number.isNaN(opened) || Number.isNaN(sent)) return true;
    return sent >= opened - CLOCK_SKEW_MS;
}

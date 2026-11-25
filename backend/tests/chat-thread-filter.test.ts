// Which stored messages a conversation may show.
//   npm test
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { belongsToThread, CLOCK_SKEW_MS } from "#services/chat-thread-filter";

const opened = new Date("2026-11-25T07:07:41.923Z");
const thread = { buyer_id: 5, seller_id: 3, created_at: opened.toISOString() };
const at = (offsetMs: number) => new Date(opened.getTime() + offsetMs).toISOString();

describe("belongsToThread", () => {
    test("keeps the buyer's and the seller's messages from after the thread opened", () => {
        assert.equal(belongsToThread({ sender_id: 5, sent_at: at(60_000) }, thread), true);
        assert.equal(belongsToThread({ sender_id: 3, sent_at: at(90_000) }, thread), true);
    });

    test("drops a message from someone who is not in the thread", () => {
        assert.equal(belongsToThread({ sender_id: 4, sent_at: at(60_000) }, thread), false);
    });

    test("drops a leftover from a reused id, even one sent by a party", () => {
        // The case found in the shared data: an old thread's messages, weeks
        // before this conversation existed, one of them from this seller.
        const weeksBefore = at(-27 * 24 * 60 * 60_000);
        assert.equal(belongsToThread({ sender_id: 3, sent_at: weeksBefore }, thread), false);
        assert.equal(belongsToThread({ sender_id: 4, sent_at: weeksBefore }, thread), false);
    });

    test("keeps a first message stamped slightly before the thread by a lagging clock", () => {
        assert.equal(belongsToThread({ sender_id: 5, sent_at: at(-30_000) }, thread), true);
        assert.equal(belongsToThread({ sender_id: 5, sent_at: at(-CLOCK_SKEW_MS) }, thread), true);
        assert.equal(belongsToThread({ sender_id: 5, sent_at: at(-CLOCK_SKEW_MS - 1) }, thread), false);
    });

    test("reads created_at in the form the conversation summary gives it", () => {
        // ConversationModel maps created_at with String(Date).
        const summary = { ...thread, created_at: String(opened) };
        assert.equal(belongsToThread({ sender_id: 5, sent_at: at(60_000) }, summary), true);
        assert.equal(belongsToThread({ sender_id: 5, sent_at: at(-24 * 60 * 60_000) }, summary), false);
    });

    test("ids compare as numbers whatever type they arrive as", () => {
        const stringIds = { buyer_id: "5" as unknown as number, seller_id: "3" as unknown as number, created_at: thread.created_at };
        assert.equal(belongsToThread({ sender_id: 5, sent_at: at(1000) }, stringIds), true);
    });

    test("an unreadable date leaves only the sender check", () => {
        assert.equal(belongsToThread({ sender_id: 5, sent_at: "not a date" }, thread), true);
        assert.equal(belongsToThread({ sender_id: 4, sent_at: "not a date" }, thread), false);
    });
});

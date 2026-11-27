// Reporting a listing or an account: what is accepted and what is refused.
//   npm test
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { fileReport, ReportError, ReportStore, REPORT_REASON_MAX } from "#services/moderation-report.service";

const BUYER = 7;
const SELLER = 3;
const LISTING = 9;

type Row = { reporterId: number; reportedUserId: number; productId: number | null; reason: string };

/** A listing 9 sold by user 3, users 3 and 7 active, 99 deleted. Mirrors the open-report unique indexes. */
function memoryStore() {
    const rows: Row[] = [];
    const store: ReportStore = {
        findListingSeller: async (productId) => (productId === LISTING ? SELLER : undefined),
        isActiveUser: async (userId) => userId === BUYER || userId === SELLER,
        insert: async (row) => {
            const clash = rows.some((r) => r.reporterId === row.reporterId
                && (row.productId === null
                    ? r.productId === null && r.reportedUserId === row.reportedUserId
                    : r.productId === row.productId));
            if (clash) return undefined;
            rows.push(row);
            return rows.length;
        },
    };
    return { store, rows };
}

async function refusal(promise: Promise<unknown>): Promise<ReportError> {
    try {
        await promise;
    } catch (error) {
        assert.ok(error instanceof ReportError, `expected a ReportError, got ${error}`);
        return error;
    }
    assert.fail('expected the report to be refused');
}

describe('fileReport', () => {
    test('a listing report records the listing and its seller, with the reason trimmed', async () => {
        const { store, rows } = memoryStore();
        const id = await fileReport(BUYER, { kind: 'listing', productId: LISTING }, '  Photos are not of this produce  ', store);
        assert.equal(id, 1);
        assert.deepEqual(rows, [{ reporterId: BUYER, reportedUserId: SELLER, productId: LISTING, reason: 'Photos are not of this produce' }]);
    });

    test('a profile report records the account with no listing', async () => {
        const { store, rows } = memoryStore();
        await fileReport(BUYER, { kind: 'user', userId: SELLER }, 'Asked me to pay outside the app', store);
        assert.deepEqual(rows, [{ reporterId: BUYER, reportedUserId: SELLER, productId: null, reason: 'Asked me to pay outside the app' }]);
    });

    test('a reason is required and has a limit', async () => {
        const { store, rows } = memoryStore();
        for (const reason of [undefined, '', '   ', 42]) {
            const error = await refusal(fileReport(BUYER, { kind: 'listing', productId: LISTING }, reason, store));
            assert.equal(error.status, 400);
        }
        const tooLong = await refusal(fileReport(BUYER, { kind: 'user', userId: SELLER }, 'x'.repeat(REPORT_REASON_MAX + 1), store));
        assert.equal(tooLong.status, 400);
        await fileReport(BUYER, { kind: 'user', userId: SELLER }, 'x'.repeat(REPORT_REASON_MAX), store);
        assert.equal(rows.length, 1);
    });

    test('nobody can report themselves or their own listing', async () => {
        const { store, rows } = memoryStore();
        assert.equal((await refusal(fileReport(SELLER, { kind: 'listing', productId: LISTING }, 'mine', store))).status, 400);
        assert.equal((await refusal(fileReport(BUYER, { kind: 'user', userId: BUYER }, 'me', store))).status, 400);
        assert.equal(rows.length, 0);
    });

    test('a listing or account that is not there is a 404', async () => {
        const { store } = memoryStore();
        assert.equal((await refusal(fileReport(BUYER, { kind: 'listing', productId: 404 }, 'gone', store))).status, 404);
        assert.equal((await refusal(fileReport(BUYER, { kind: 'listing', productId: Number('abc') }, 'bad id', store))).status, 404);
        assert.equal((await refusal(fileReport(BUYER, { kind: 'user', userId: 99 }, 'deleted', store))).status, 404);
    });

    test('a second open report on the same thing is a 409, but listing and profile are separate', async () => {
        const { store, rows } = memoryStore();
        await fileReport(BUYER, { kind: 'listing', productId: LISTING }, 'first', store);
        const again = await refusal(fileReport(BUYER, { kind: 'listing', productId: LISTING }, 'second', store));
        assert.equal(again.status, 409);
        assert.match(again.message, /already reported this listing/);

        await fileReport(BUYER, { kind: 'user', userId: SELLER }, 'the seller too', store);
        const againProfile = await refusal(fileReport(BUYER, { kind: 'user', userId: SELLER }, 'again', store));
        assert.equal(againProfile.status, 409);
        assert.match(againProfile.message, /already reported this profile/);
        assert.equal(rows.length, 2);
    });
});

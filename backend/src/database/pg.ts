import fs from 'fs';
import path from 'path';
import { Pool, PoolClient, types } from 'pg';
import { requireEnv } from '../config/env';

// The app's relational database: PostgreSQL on AWS RDS, schema in
// database/migrations (applied by `npm run db:migrate`). Every model queries
// through this pool; chat messages are in DynamoDB (models/message.model.ts).

// Rows come back in the shapes the API has always sent:
//   numeric (prices, quantities) and bigint (COUNT, SUM) as numbers - every
//   value here fits a JS number;
//   date (harvest_date, recorded_at) as 'YYYY-MM-DD' - parsing it would give
//   local midnight, a day off in UTC;
//   timestamptz as an ISO 8601 UTC string, which the app parses.
types.setTypeParser(types.builtins.NUMERIC, parseFloat);
types.setTypeParser(types.builtins.INT8, (value) => parseInt(value, 10));
types.setTypeParser(types.builtins.DATE, (value) => value);
const parseTimestamptz = types.getTypeParser(types.builtins.TIMESTAMPTZ);
types.setTypeParser(types.builtins.TIMESTAMPTZ, (value) => (parseTimestamptz(value) as Date).toISOString());

// AWS RDS CA bundle: https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
const caPath = process.env.PGSSLROOTCERT ?? path.resolve(__dirname, '../../certs/global-bundle.pem');

export const pool = new Pool({
    host: requireEnv('PGHOST'),
    port: Number(process.env.PGPORT ?? 5432),
    database: requireEnv('PGDATABASE'),
    user: requireEnv('PGUSER'),
    password: requireEnv('PGPASSWORD'),
    max: 10,
    // Fail fast instead of hanging forever when RDS is unreachable
    connectionTimeoutMillis: 10_000,
    // RDS requires an encrypted connection; verify the server against the RDS CA.
    // PGSSLMODE=disable is for a Postgres on your own machine only.
    ssl: process.env.PGSSLMODE === 'disable'
        ? false
        : { ca: fs.readFileSync(caPath, 'utf8'), rejectUnauthorized: true },
});

pool.on('error', (err) => {
    console.error('Unexpected Postgres pool error:', err);
});

/** The pool, or the client of an open transaction: model functions accept either. */
export type Queryable = Pool | PoolClient;

/**
 * Runs `work` on one connection between BEGIN and COMMIT; a throw rolls it all back.
 * `snapshot` makes it read-only and has every query in it see the same data
 * (REPEATABLE READ), for summaries built from several queries.
 */
export async function withTransaction<T>(work: (client: PoolClient) => Promise<T>, { snapshot = false } = {}): Promise<T> {
    const client = await pool.connect();
    let broken: Error | undefined;
    try {
        await client.query(snapshot ? 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY' : 'BEGIN');
        const result = await work(client);
        await client.query('COMMIT');
        return result;
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (rollbackError) {
            // Do not hand a connection in an unknown state back to the pool.
            broken = rollbackError as Error;
        }
        throw error;
    } finally {
        client.release(broken);
    }
}

/**
 * Whether a query failed on a UNIQUE index (SQLSTATE 23505), optionally a
 * specific one. Requests run concurrently, so two can pass the same "does it
 * exist yet?" check; the index is what finally says no.
 */
export const isUniqueViolation = (error: unknown, constraint?: string): boolean => {
    const { code, constraint: name } = (error ?? {}) as { code?: unknown; constraint?: unknown };
    return code === '23505' && (constraint === undefined || name === constraint);
};

/**
 * Whether a number can be a SERIAL/IDENTITY id. Postgres answers a NaN or
 * out-of-range integer parameter with an error, so lookups by an id taken
 * from the URL check it first and simply find nothing.
 */
export const isRowId = (value: number): boolean => Number.isInteger(value) && value > 0 && value <= 2_147_483_647;

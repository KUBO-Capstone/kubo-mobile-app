import fs from 'fs';
import path from 'path';
import { pool } from './pg';

// Applies database/migrations/*.sql in file-name order, each once, and
// records it in schema_migrations. Every file wraps itself in BEGIN/COMMIT
// and is written to be re-runnable (IF NOT EXISTS, guarded DO blocks), so a
// database that got 001-003 by hand before this runner existed is safe to
// migrate: those files just find their tables already there.
//
// Resolved from the backend folder so it works from src/ and dist/ alike.
const migrationsDir = path.resolve(__dirname, '../../src/database/migrations');
// pg_advisory_lock key: two teammates migrating the shared RDS at once take turns.
const lockKey = 4_405_150_001;

const migrationFiles = (): string[] => fs.readdirSync(migrationsDir).filter((file) => file.endsWith('.sql')).sort();

/** Migration files not yet recorded as applied. */
export async function pendingMigrations(): Promise<string[]> {
    const table = await pool.query(`SELECT to_regclass('public.schema_migrations') AS name`);
    if (!table.rows[0].name) return migrationFiles();
    const applied = await pool.query<{ filename: string }>('SELECT filename FROM schema_migrations');
    const done = new Set(applied.rows.map((row) => row.filename));
    return migrationFiles().filter((file) => !done.has(file));
}

/** Applies every pending migration; returns the files it applied. */
export async function migrate(log: (line: string) => void = console.log): Promise<string[]> {
    const client = await pool.connect();
    try {
        await client.query('SELECT pg_advisory_lock($1)', [lockKey]);
        await client.query(`
            CREATE TABLE IF NOT EXISTS schema_migrations (
                filename   text        PRIMARY KEY,
                applied_at timestamptz NOT NULL DEFAULT now()
            )
        `);
        const pending = await pendingMigrations();
        for (const file of pending) {
            log(`Applying ${file}`);
            try {
                // No parameters, so the whole file goes as one multi-statement query.
                await client.query(fs.readFileSync(path.join(migrationsDir, file), 'utf8'));
            } catch (error) {
                // A failed statement leaves the file's own transaction open and aborted.
                await client.query('ROLLBACK');
                throw new Error(`${file} failed: ${error instanceof Error ? error.message : String(error)}`);
            }
            await client.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
        }
        return pending;
    } finally {
        await client.query('SELECT pg_advisory_unlock($1)', [lockKey]).catch(() => undefined);
        client.release();
    }
}

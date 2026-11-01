import 'dotenv/config'; // must stay first: database/pg reads PG* when imported
import { migrate } from '#database/migrate';
import { pool } from '#database/pg';
import { seed } from './seed';

// Empties every table in the database PGHOST/PGDATABASE point at, brings the
// schema up to date and reseeds it. On the shared RDS that wipes everyone's
// data, so it asks for --yes:
//   npm run db:reset -- --yes
async function main(): Promise<void> {
    const target = `${process.env.PGHOST}/${process.env.PGDATABASE}`;
    if (!process.argv.includes('--yes')) {
        console.error(`This deletes every row in ${target}. Run again with --yes to go ahead:\n  npm run db:reset -- --yes`);
        process.exitCode = 1;
        return;
    }
    await migrate();
    const { rows } = await pool.query<{ name: string }>(`
        SELECT quote_ident(tablename) AS name FROM pg_tables
        WHERE schemaname = 'public' AND tablename <> 'schema_migrations'
    `);
    // Ids keep counting up instead of restarting at 1: DynamoDB keeps chat
    // messages under their conversation_id, and a login token names its
    // user_id, so a reused id would hand an old thread or session to
    // whoever gets that id next.
    if (rows.length > 0) {
        await pool.query(`TRUNCATE ${rows.map((row) => row.name).join(', ')} CASCADE`);
    }
    console.log(`Emptied ${rows.length} tables in ${target}.`);
    await seed();
}

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .finally(() => pool.end());

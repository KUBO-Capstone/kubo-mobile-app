import 'dotenv/config'; // must stay first: database/pg reads PG* when imported
import { migrate } from '#database/migrate';
import { pool } from '#database/pg';

// Brings the database named by PGHOST/PGDATABASE up to the schema in
// database/migrations. Safe to run again; it only applies what is missing.
//   npm run db:migrate
migrate()
    .then((applied) => {
        console.log(applied.length ? `Applied ${applied.length} migration(s).` : 'Database is up to date.');
    })
    .catch((error) => {
        console.error(error instanceof Error ? error.message : error);
        process.exitCode = 1;
    })
    .finally(() => pool.end());

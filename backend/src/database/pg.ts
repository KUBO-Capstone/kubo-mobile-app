import { Pool } from 'pg';
import { requireEnv } from '../config/aws';

export const pool = new Pool({
    host: requireEnv('PGHOST'),
    port: Number(process.env.PGPORT ?? 5432),
    database: requireEnv('PGDATABASE'),
    user: requireEnv('PGUSER'),
    password: requireEnv('PGPASSWORD'),
    max: 10,
    // RDS requires an encrypted connection. This encrypts but does not verify the
    // server certificate. Before production, download the AWS RDS CA bundle and use
    // { ca: fs.readFileSync('global-bundle.pem'), rejectUnauthorized: true }.
    ssl: { rejectUnauthorized: false },
});

pool.on('error', (err) => {
    console.error('Unexpected Postgres pool error:', err);
});
import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { requireEnv } from '../config/env';

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
    ssl: { ca: fs.readFileSync(caPath, 'utf8'), rejectUnauthorized: true },
});

pool.on('error', (err) => {
    console.error('Unexpected Postgres pool error:', err);
});

/**
 * Checks that the app can reach RDS, DynamoDB and S3 with the current .env.
 * Run:  npx tsx src/scripts/test-connections.ts
 */
import 'dotenv/config'; // must stay first so env vars exist before other imports read them
import { DescribeTableCommand } from '@aws-sdk/client-dynamodb';
import { HeadBucketCommand } from '@aws-sdk/client-s3';
import { dynamoClient, requireEnv, s3 } from '../config/aws';
import { pool } from '../database/pg';

async function check(name: string, fn: () => Promise<string>): Promise<boolean> {
    try {
        console.log(`OK    ${name}: ${await fn()}`);
        return true;
    } catch (err) {
        console.error(`FAIL  ${name}: ${(err as Error).message}`);
        return false;
    }
}

async function main(): Promise<void> {
    const results = [
        await check('RDS Postgres', async () => {
            const res = await pool.query('SELECT version() AS v');
            return String(res.rows[0].v).split(',')[0];
        }),
        await check('DynamoDB', async () => {
            const table = process.env.DDB_MESSAGES_TABLE ?? 'kubo_messages';
            const res = await dynamoClient.send(new DescribeTableCommand({ TableName: table }));
            return `table "${table}" is ${res.Table?.TableStatus}`;
        }),
        await check('S3', async () => {
            const bucket = requireEnv('S3_BUCKET');
            await s3.send(new HeadBucketCommand({ Bucket: bucket }));
            return `bucket "${bucket}" is reachable`;
        }),
    ];
    await pool.end();
    process.exit(results.every(Boolean) ? 0 : 1);
}

main();
/**
 * Creates the DynamoDB messages table if it does not exist, or checks the
 * key schema of the existing one. Safe to re-run.
 * Run:  npm run ddb:create-messages
 */
import 'dotenv/config'; // must stay first so env vars exist before other imports read them
import {
    CreateTableCommand,
    DescribeTableCommand,
    ResourceNotFoundException,
    waitUntilTableExists,
} from '@aws-sdk/client-dynamodb';
import { dynamoClient } from '../config/aws';

// Key names must match models/message.model.ts.
const TableName = process.env.DDB_MESSAGES_TABLE ?? 'ChatMessages';
const EXPECTED = 'chatRoomId:HASH:S, timestamp:RANGE:S';

async function main(): Promise<void> {
    try {
        const { Table } = await dynamoClient.send(new DescribeTableCommand({ TableName }));
        const types = new Map(Table?.AttributeDefinitions?.map((a) => [a.AttributeName, a.AttributeType]));
        const actual = (Table?.KeySchema ?? [])
            .map((k) => `${k.AttributeName}:${k.KeyType}:${types.get(k.AttributeName)}`)
            .join(', ');
        if (actual !== EXPECTED) {
            throw new Error(`Table "${TableName}" exists with keys [${actual}], expected [${EXPECTED}]`);
        }
        console.log(`Table "${TableName}" already exists (${Table?.TableStatus}) with the expected keys.`);
        return;
    } catch (err) {
        if (!(err instanceof ResourceNotFoundException)) throw err;
    }

    await dynamoClient.send(new CreateTableCommand({
        TableName,
        BillingMode: 'PAY_PER_REQUEST',
        AttributeDefinitions: [
            { AttributeName: 'chatRoomId', AttributeType: 'S' },
            { AttributeName: 'timestamp', AttributeType: 'S' },
        ],
        KeySchema: [
            { AttributeName: 'chatRoomId', KeyType: 'HASH' },
            { AttributeName: 'timestamp', KeyType: 'RANGE' },
        ],
    }));
    await waitUntilTableExists({ client: dynamoClient, maxWaitTime: 120 }, { TableName });
    console.log(`Created table "${TableName}".`);
}

main().catch((err) => {
    console.error((err as Error).message);
    process.exit(1);
});

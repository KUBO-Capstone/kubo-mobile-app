import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';

export function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) throw new Error(`Missing required environment variable: ${name}`);
    return value;
}

const region = requireEnv('AWS_REGION');

// Credentials are NOT set here on purpose. The SDK finds them automatically:
//   - locally: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY in .env, or `aws configure`
//   - on AWS (EC2 / ECS / Lambda): the attached IAM role
// Never hardcode keys or commit them.

/** Low-level DynamoDB client (used for table management). */
export const dynamoClient = new DynamoDBClient({ region });

/** Document client: reads/writes plain JS objects instead of {S: "..."} attribute values. */
export const ddb = DynamoDBDocumentClient.from(dynamoClient, {
    marshallOptions: { removeUndefinedValues: true },
});

export const s3 = new S3Client({ region });
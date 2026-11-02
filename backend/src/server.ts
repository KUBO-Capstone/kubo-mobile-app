// Must stay first: config/aws.ts reads AWS_REGION as soon as it is imported.
import "dotenv/config";
import { createServer } from "http";
import app from "./app";
import { pendingMigrations } from "./database/migrate";
import { pool } from "./database/pg";
import { scheduleMarketImport } from "./market/market-import";
import { initSocket } from "./services/socket.service";

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || "0.0.0.0";

// Refuse to start rather than answer every request with a 500: the database
// must be reachable and have every migration applied (`npm run db:migrate`).
async function start(): Promise<void> {
    const pending = await pendingMigrations();
    if (pending.length > 0) {
        throw new Error(`Postgres ${process.env.PGDATABASE} is missing migrations ${pending.join(', ')}. Run: npm run db:migrate`);
    }

    // Express and Socket.IO share one port; see services/socket.service.ts.
    const server = createServer(app);
    initSocket(server);

    server.listen(PORT, HOST, () => {
        console.log(`Server running on http://${HOST}:${PORT} (Postgres ${process.env.PGHOST}/${process.env.PGDATABASE})`);
        // Daily DA Bantay Presyo refresh of Market Watch; see market/market-import.ts.
        scheduleMarketImport();
    });
}

start().catch(async (error) => {
    console.error(`Cannot start: ${error instanceof Error ? error.message : String(error)}`);
    await pool.end().catch(() => undefined);
    process.exit(1);
});

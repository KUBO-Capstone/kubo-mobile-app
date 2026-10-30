// Must stay first: config/aws.ts reads AWS_REGION as soon as it is imported.
import "dotenv/config";
import { createServer } from "http";
import app from "./app";
import { initDb } from "./config/database";
import { scheduleMarketImport } from "./market/market-import";
import { initSocket } from "./services/socket.service";

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || "0.0.0.0";

initDb();

// Express and Socket.IO share one port; see services/socket.service.ts.
const server = createServer(app);
initSocket(server);

server.listen(PORT, HOST, () => {
    console.log(`Server running on http://${HOST}:${PORT}`);
    // Daily DA Bantay Presyo refresh of Market Watch; see market/market-import.ts.
    scheduleMarketImport();
});

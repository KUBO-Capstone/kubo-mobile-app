import dotenv from "dotenv";
import app from "./app";
import { initDb } from "./config/database";
import { scheduleMarketImport } from "./market/market-import";

dotenv.config();

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || "0.0.0.0";

initDb();

app.listen(PORT, HOST, () => {
    console.log(`Server running on http://${HOST}:${PORT}`);
    // Daily DA Bantay Presyo refresh of Market Watch; see market/market-import.ts.
    scheduleMarketImport();
});

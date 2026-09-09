import dotenv from "dotenv";
import app from "./app";
import { initDb } from "./config/database";

const PORT = process.env.PORT || 3000;

initDb();

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
import express, { Application } from "express";
import cors from "cors";
import routes from "./routes";
import { errorHandler } from "./middleware/error.middleware";
import path from "path";

const app: Application = express();

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.resolve(__dirname, '../uploads'), { maxAge: '1d', immutable: true }));
app.use("/api", routes);
app.use(errorHandler);

export default app;
import express, { Application } from "express";
import cors from "cors";
import routes from "./routes";
import { errorHandler } from "./middleware/error.middleware";
import { exposeMediaUrls } from "./middleware/media.middleware";

const app: Application = express();

// Any origin, as before. WWW-Authenticate is how requireAuth says a token is
// no longer good (see middleware/auth.middleware.ts); a browser only lets
// cross-origin code read response headers that are named here.
app.use(cors({ exposedHeaders: ['WWW-Authenticate'] }));
app.use(express.json());
// Photos are served by S3, not by this server; responses carry URLs the app
// can load straight from the bucket (or MEDIA_BASE_URL).
app.use(exposeMediaUrls);
app.use("/api", routes);
app.use(errorHandler);

export default app;

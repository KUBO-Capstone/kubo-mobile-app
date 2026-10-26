import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { createReport } from "#controllers/report.controller";

const router = Router();
router.use(requireAuth);
router.post('/', createReport);

export default router;
import { Router } from "express";
import { getBagsakanCenters } from "#controllers/bagsakan.controller";

const router = Router();
router.get('/', getBagsakanCenters);

export default router;

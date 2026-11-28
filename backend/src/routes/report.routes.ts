import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { createReport, reportListing, reportUser } from "#controllers/report.controller";

const router = Router();
router.use(requireAuth);
// App feedback and bug reports.
router.post('/', createReport);
// A listing or an account, from the listing page and the profile.
router.post('/listings/:id', reportListing);
router.post('/users/:id', reportUser);

export default router;

import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { getSavedListings, saveListing, unsaveListing } from "#controllers/saved-listing.controller";

const router = Router();
// Every route here acts as, or reads for, the signed-in user.
router.use(requireAuth);
router.get('/', getSavedListings);
router.post('/', saveListing);
router.delete('/:productId', unsaveListing);

export default router;

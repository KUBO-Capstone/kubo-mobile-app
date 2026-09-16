import { Router } from "express";
import { getSavedListings, saveListing, unsaveListing } from "#controllers/saved-listing.controller";

const router = Router();
router.get('/', getSavedListings);
router.post('/', saveListing);
router.delete('/:productId', unsaveListing);

export default router;

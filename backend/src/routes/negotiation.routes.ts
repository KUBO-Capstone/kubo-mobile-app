import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { createNegotiation, getNegotiation, getNegotiations, markNegotiationCelebrated, respondToNegotiation } from "#controllers/negotiation.controller";

const router = Router();
// Every route here acts as, or reads for, the signed-in user.
router.use(requireAuth);
router.get('/', getNegotiations);
router.get('/:id', getNegotiation);
router.post('/', createNegotiation);
router.patch('/:id', respondToNegotiation);
router.post('/:id/celebrated', markNegotiationCelebrated);

export default router;

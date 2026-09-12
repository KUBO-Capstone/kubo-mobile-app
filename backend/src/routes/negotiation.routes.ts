import { Router } from "express";
import { createNegotiation, getNegotiation, getNegotiations, respondToNegotiation } from "#controllers/negotiation.controller";

const router = Router();
router.get('/', getNegotiations);
router.get('/:id', getNegotiation);
router.post('/', createNegotiation);
router.patch('/:id', respondToNegotiation);

export default router;

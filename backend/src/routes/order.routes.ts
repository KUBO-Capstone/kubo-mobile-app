import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { createOrder, getOrder, getOrders, updateOrder } from "#controllers/order.controller";

const router = Router();
// Every route here acts as, or reads for, the signed-in user.
router.use(requireAuth);
router.get('/', getOrders);
router.get('/:id', getOrder);
router.post('/', createOrder);
router.patch('/:id', updateOrder);

export default router;

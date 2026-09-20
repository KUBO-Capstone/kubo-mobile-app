import { Router } from "express";
import { createOrder, getOrder, getOrders, updateOrder } from "#controllers/order.controller";

const router = Router();
router.get('/', getOrders);
router.get('/:id', getOrder);
router.post('/', createOrder);
router.patch('/:id', updateOrder);

export default router;

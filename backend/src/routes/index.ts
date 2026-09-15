import { Router } from "express";
import authRoutes from "./auth.routes";
import userRoutes from "./user.routes";
import productRoutes from "./product.routes";
import bagsakanRoutes from "./bagsakan.routes";
import negotiationRoutes from "./negotiation.routes";
import conversationRoutes from "./conversation.routes";

const router = Router();

router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/products', productRoutes);
router.use('/bagsakan-centers', bagsakanRoutes);
router.use('/negotiations', negotiationRoutes);
router.use('/conversations', conversationRoutes);

export default router;
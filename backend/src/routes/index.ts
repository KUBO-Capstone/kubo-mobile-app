import { Router } from "express";
import authRoutes from "./auth.routes";
import userRoutes from "./user.routes";
import productRoutes from "./product.routes";
import bagsakanRoutes from "./bagsakan.routes";
import negotiationRoutes from "./negotiation.routes";
import conversationRoutes from "./conversation.routes";
import marketRoutes from "./market.routes";
import savedListingRoutes from "./saved-listing.routes";
import orderRoutes from "./order.routes";
import notificationRoutes from "./notification.routes";

const router = Router();

router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/products', productRoutes);
router.use('/bagsakan-centers', bagsakanRoutes);
router.use('/negotiations', negotiationRoutes);
router.use('/conversations', conversationRoutes);
router.use('/market', marketRoutes);
router.use('/saved-listings', savedListingRoutes);
router.use('/orders', orderRoutes);
router.use('/notifications', notificationRoutes);

export default router;
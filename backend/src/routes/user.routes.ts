import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { getUsers, createUser, addUserAddress, addFarmAddress } from "#controllers/user.controller";

const router = Router();

router.get('/', requireAuth, getUsers);
router.post('/', createUser);
router.post('/:id/address', requireAuth, addUserAddress);
router.put('/:id/address', requireAuth, addUserAddress);
router.post('/:id/farm-address', requireAuth, addFarmAddress);
router.put('/:id/farm-address', requireAuth, addFarmAddress);

export default router;
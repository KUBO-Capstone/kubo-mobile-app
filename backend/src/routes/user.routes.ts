import { Router } from "express";
import { getUsers, createUser, addUserAddress, addFarmAddress } from "#controllers/user.controller";

const router = Router();

router.get('/', getUsers);
router.post('/', createUser);
router.post('/:id/address', addUserAddress);
router.put('/:id/address', addUserAddress);
router.post('/:id/farm-address', addFarmAddress);
router.put('/:id/farm-address', addFarmAddress);

export default router;
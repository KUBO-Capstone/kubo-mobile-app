import { Router } from "express";
import { getUsers, createUser, addUserAddress} from "#controllers/user.controller";

const router = Router();

router.get('/', getUsers);
router.post('/', createUser);
router.post('/:id/address', addUserAddress);
router.put('/:id/address', addUserAddress);

export default router;
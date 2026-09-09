import { Router } from "express";
import { login } from "#controllers/auth.controller";
import { createUser } from "#controllers/user.controller";

const router = Router();

router.post('/login', login);
router.post('/register', createUser);

export default router;

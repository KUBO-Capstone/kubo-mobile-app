import { Router } from "express";
import { googleLogin, login, me } from "#controllers/auth.controller";
import { createUser } from "#controllers/user.controller";
import { requireAuth } from "#middleware/auth.middleware";

const router = Router();

router.post('/login', login);
router.post('/google', googleLogin);
router.post('/register', createUser);
router.get('/me', requireAuth, me);

export default router;

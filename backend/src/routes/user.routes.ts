import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import crypto from 'crypto';
import fs from 'fs';
import multer from 'multer';
import path from 'path';
import { getUsers, createUser, addUserAddress, addFarmAddress, getProfile, updateProfile, uploadProfilePhoto, deleteProfilePhoto } from "#controllers/user.controller";

const router = Router();
const uploadDirectory = path.resolve(__dirname, '../../uploads/profile');
fs.mkdirSync(uploadDirectory, { recursive: true });
const profileUpload = multer({
	storage: multer.diskStorage({
		destination: uploadDirectory,
		filename: (_req, file, callback) => callback(null, `${crypto.randomUUID()}${path.extname(file.originalname).toLowerCase()}`),
	}),
	limits: { fileSize: 5 * 1024 * 1024 },
	fileFilter: (_req, file, callback) => callback(null, ['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)),
});

router.get('/', requireAuth, getUsers);
router.post('/', createUser);
router.get('/:id/profile', getProfile);
router.patch('/:id/profile', updateProfile);
router.post('/:id/profile/photo', profileUpload.single('photo'), uploadProfilePhoto);
router.delete('/:id/profile/photo', deleteProfilePhoto);
router.post('/:id/address', addUserAddress);
router.put('/:id/address', addUserAddress);
router.post('/:id/farm-address', addFarmAddress);
router.put('/:id/farm-address', addFarmAddress);

export default router;
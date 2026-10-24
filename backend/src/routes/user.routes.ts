import { Router } from "express";
import crypto from 'crypto';
import fs from 'fs';
import multer from 'multer';
import path from 'path';
import { getUsers, createUser, addUserAddress, addFarmAddress, getProfile, updateProfile, uploadProfilePhoto, deleteProfilePhoto } from "#controllers/user.controller";
import { attachAuth, requireAuth, requireOwner } from "#middleware/auth.middleware";

const router = Router();
const uploadDirectory = path.resolve(__dirname, '../../uploads/profile');
fs.mkdirSync(uploadDirectory, { recursive: true });
const profileUpload = multer({
	storage: multer.diskStorage({
		destination: uploadDirectory,
		filename: (_req, file, callback) => callback(null, `${crypto.randomUUID()}${path.extname(file.originalname).toLowerCase()}`),
	}),
	limits: { fileSize: 5 * 1024 * 1024 },
	fileFilter: (_req, file, callback) => {
		const extension = path.extname(file.originalname).toLowerCase();
		const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
		const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/octet-stream'];
		callback(null, allowedExtensions.includes(extension) && allowedMimeTypes.includes(file.mimetype));
	},
});

router.get('/', getUsers);
router.post('/', createUser);
router.get('/:id/profile', attachAuth, getProfile);
router.patch('/:id/profile', requireAuth, requireOwner, updateProfile);
router.post('/:id/profile/photo', requireAuth, requireOwner, profileUpload.single('photo'), uploadProfilePhoto);
router.delete('/:id/profile/photo', requireAuth, requireOwner, deleteProfilePhoto);
router.post('/:id/address', requireAuth, requireOwner, addUserAddress);
router.put('/:id/address', requireAuth, requireOwner, addUserAddress);
router.post('/:id/farm-address', requireAuth, requireOwner, addFarmAddress);
router.put('/:id/farm-address', requireAuth, requireOwner, addFarmAddress);

export default router;
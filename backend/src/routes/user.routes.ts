import { Router } from "express";
import { getUsers, createUser, addUserAddress, addFarmAddress, getProfile, updateProfile, uploadProfilePhoto, deleteProfilePhoto, changePassword, updateUserAddress, choosePreferredAddress } from "#controllers/user.controller";
import { getUserReviews } from "#controllers/review.controller";
import { getEarnings } from "#controllers/earnings.controller";
import { attachAuth, requireAuth, requireOwner } from "#middleware/auth.middleware";
import { receiveImages } from "#controllers/upload.controller";

const router = Router();
const receiveProfilePhoto = receiveImages({
    field: 'photo',
    folder: 'profiles',
    maxFiles: 1,
    maxBytes: 5 * 1024 * 1024,
    messages: {
        LIMIT_FILE_SIZE: 'Profile photo must be 5 MB or smaller',
        LIMIT_FILE_COUNT: 'Choose one profile photo',
        LIMIT_UNEXPECTED_FILE: 'Choose one profile photo',
    },
});

router.get('/', requireAuth, getUsers);
router.post('/', createUser);
router.get('/:id/profile', attachAuth, getProfile);
router.patch('/:id/profile', requireAuth, requireOwner, updateProfile);
router.get('/:id/reviews', getUserReviews);
router.get('/:id/earnings', requireAuth, requireOwner, getEarnings);
router.post('/:id/profile/photo', requireAuth, requireOwner, receiveProfilePhoto, uploadProfilePhoto);
router.delete('/:id/profile/photo', requireAuth, requireOwner, deleteProfilePhoto);
router.post('/:id/address', requireAuth, requireOwner, addUserAddress);
router.put('/:id/address', requireAuth, requireOwner, addUserAddress);
router.patch('/:id/address', requireAuth, requireOwner, updateUserAddress);
router.patch('/:id/preferred-address', requireAuth, requireOwner, choosePreferredAddress);
router.post('/:id/farm-address', requireAuth, requireOwner, addFarmAddress);
router.put('/:id/farm-address', requireAuth, requireOwner, addFarmAddress);
router.patch('/:id/password', requireAuth, requireOwner, changePassword);

export default router;

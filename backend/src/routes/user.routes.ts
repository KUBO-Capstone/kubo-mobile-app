import { Router } from "express";
import { getUsers, createUser, addUserAddress, addFarmAddress, getProfile, updateProfile, uploadProfilePhoto, deleteProfilePhoto, changePassword, updateUserAddress, choosePreferredAddress, followUser, unfollowUser } from "#controllers/user.controller";
import { getUserReviews } from "#controllers/review.controller";
import { getEarnings } from "#controllers/earnings.controller";
import { getFulfillment, updateFulfillment } from "#controllers/fulfillment.controller";
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
// The signed-in user follows or unfollows :id.
router.post('/:id/follow', requireAuth, followUser);
router.delete('/:id/follow', requireAuth, unfollowUser);
router.get('/:id/reviews', getUserReviews);
// The seller's figures: only ever for the seller themselves.
router.get('/:id/earnings', requireAuth, requireOwner, getEarnings);
// Centers and couriers the seller works with; buyers read it, the seller sets it.
router.get('/:id/fulfillment', getFulfillment);
router.put('/:id/fulfillment', requireAuth, requireOwner, updateFulfillment);
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

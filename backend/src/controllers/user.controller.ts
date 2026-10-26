import { Request, Response } from "express";
import fs from "fs";
import path from "path";
import { UserModel } from "#models/user.model";
import { signToken } from "#utils/token";
import { authUserId } from "#middleware/auth.middleware";
import { verifyPassword } from "#utils/password";

export const getUsers = (req: Request, res: Response): void => {
    const users = UserModel.findAll();
    res.json({
        success: true,
        data: users.map(({ password_hash: _passwordHash, ...user }) => user),
    });
};

export const createUser = (req: Request, res: Response): void => {
    const { first_name, last_name, email, password, contact_number, role, region, province, city_municipality, zip_code } = req.body;

    if (!first_name || !last_name || !email || !password || !contact_number ||
        !region || !city_municipality || !zip_code || (region !== 'NCR' && !province)) {
        res.status(400).json({ success: false, message: "All account and address fields are required" });
        return;
    }
    if (typeof zip_code !== 'string' || !/^\d{4}$/.test(zip_code.trim())) {
        res.status(400).json({ success: false, message: "ZIP code must contain exactly 4 digits" });
        return;
    }

    const normalizedEmail = email.trim().toLowerCase();
    if (UserModel.findByEmail(normalizedEmail)) {
        res.status(409).json({ success: false, message: "An account with this email already exists" });
        return;
    }

    // Admins are never self-registered; anything but 'farmer' signs up as a consumer.
    const requestedRole = role === 'farmer' ? role : 'consumer';
    const user = UserModel.createWithAddress(
        {
            first_name: first_name.trim(),
            last_name: last_name.trim(),
            email: normalizedEmail,
            password,
            contact_number: contact_number.trim(),
            role: requestedRole,
        },
        {
            region: region.trim(),
            province: (province ?? '').trim(),
            city_municipality: city_municipality.trim(),
            zip_code: zip_code.trim(),
        },
    );
    const { password_hash: _passwordHash, ...safeUser } = user;
    // Registering signs the user in, same as login.
    res.status(201).json({ success: true, data: { ...safeUser, token: signToken(user.user_id, user.role) } });
};

const publicUser = (
    user: ReturnType<typeof UserModel.findById> | ReturnType<typeof UserModel.findProfile>,
    viewerId?: number,
) => {
    if (!user) return undefined;
    const { password_hash: _passwordHash, ...safeUser } = user;
    if (viewerId !== user.user_id) {
        const visibleUser: Record<string, unknown> = { ...safeUser };
        let privacy: Record<string, boolean> = {};
        try {
            privacy = JSON.parse(user.profile_privacy || '{}') as Record<string, boolean>;
        } catch (_) {
            privacy = {};
        }
        if (privacy.public_profile === false) {
            return {
                user_id: user.user_id,
                first_name: user.first_name,
                last_name: user.last_name,
                role: user.role,
                is_verified: user.is_verified,
            };
        }
        if (privacy.show_bio === false) delete visibleUser.bio;
        if (privacy.show_contact_number === false) delete visibleUser.contact_number;
        if (privacy.show_location === false) delete visibleUser.location;
        return visibleUser;
    }
    return safeUser;
};

export const getProfile = (req: Request<{ id: string }>, res: Response): void => {
    const userId = Number(req.params.id);
    if (!Number.isInteger(userId) || userId <= 0) {
        res.status(400).json({ success: false, message: 'Invalid user ID format' });
        return;
    }
    const user = UserModel.findProfile(userId);
    if (!user) {
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    res.json({ success: true, data: publicUser(user, req.authUserId) });
};

export const updateProfile = (req: Request<{ id: string }>, res: Response): void => {
    const userId = Number(req.params.id);
    const firstName = typeof req.body.first_name === 'string' ? req.body.first_name.trim() : '';
    const lastName = typeof req.body.last_name === 'string' ? req.body.last_name.trim() : '';
    const contactNumber = typeof req.body.contact_number === 'string' ? req.body.contact_number.trim() : '';
    const bio = typeof req.body.bio === 'string' ? req.body.bio.trim() : '';
    const location = typeof req.body.location === 'string' ? req.body.location.trim() : '';
    const businessName = typeof req.body.business_name === 'string' ? req.body.business_name.trim() : '';
    const businessType = typeof req.body.business_type === 'string' ? req.body.business_type.trim() : '';
    const profilePrivacy = typeof req.body.profile_privacy === 'object' && req.body.profile_privacy !== null
        ? JSON.stringify({
            public_profile: req.body.profile_privacy.public_profile !== false,
            show_bio: req.body.profile_privacy.show_bio !== false,
            show_contact_number: req.body.profile_privacy.show_contact_number !== false,
            show_location: req.body.profile_privacy.show_location !== false,
        })
        : JSON.stringify({ public_profile: true, show_bio: true, show_contact_number: true, show_location: true });
    if (!Number.isInteger(userId) || userId <= 0 || !firstName || !lastName || !contactNumber) {
        res.status(400).json({ success: false, message: 'Name and contact number are required' });
        return;
    }
    if (firstName.length > 50 || lastName.length > 50 || contactNumber.length > 20 || bio.length > 500 || location.length > 80 || businessName.length > 80 || businessType.length > 40) {
        res.status(400).json({ success: false, message: 'Profile fields exceed their allowed length' });
        return;
    }
    const user = UserModel.updateProfile(userId, {
        first_name: firstName,
        last_name: lastName,
        contact_number: contactNumber,
        bio,
        location,
        business_name: businessName,
        business_type: businessType,
        profile_privacy: profilePrivacy,
    });
    if (!user) {
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    res.json({ success: true, data: publicUser(UserModel.findProfile(userId)) });
};

export const changePassword = (req: Request<{ id: string }>, res: Response): void => {
    const userId = Number(req.params.id);
    const currentPassword = typeof req.body.current_password === 'string' ? req.body.current_password : '';
    const newPassword = typeof req.body.new_password === 'string' ? req.body.new_password : '';
    if (!Number.isInteger(userId) || userId <= 0) {
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    if (userId !== authUserId(res)) {
        res.status(403).json({ success: false, message: "You can only change your own password" });
        return;
    }
    const user = UserModel.findById(userId);
    if (!user) {
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    if (!verifyPassword(currentPassword, user.password_hash)) {
        res.status(401).json({ success: false, message: 'Current password is incorrect' });
        return;
    }
    if (newPassword.length < 8) {
        res.status(400).json({ success: false, message: 'New password must be at least 8 characters' });
        return;
    }
    UserModel.updatePassword(userId, newPassword);
    res.json({ success: true, data: { message: 'Password updated successfully' } });
};

export const uploadProfilePhoto = (req: Request<{ id: string }>, res: Response): void => {
    const userId = Number(req.params.id);
    if (!Number.isInteger(userId) || userId <= 0 || !req.file) {
        res.status(400).json({ success: false, message: 'A profile photo is required' });
        return;
    }
    const existingUser = UserModel.findById(userId);
    if (!existingUser) {
        fs.unlinkSync(req.file.path);
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    const photoUrl = `/uploads/profile/${req.file.filename}`;
    const user = UserModel.setProfilePhoto(userId, photoUrl);
    if (existingUser.profile_photo_url?.startsWith('/uploads/profile/')) {
        const previousPath = path.resolve(__dirname, '../../uploads/profile', path.basename(existingUser.profile_photo_url));
        if (fs.existsSync(previousPath)) fs.unlinkSync(previousPath);
    }
    res.json({ success: true, data: publicUser(user) });
};

export const deleteProfilePhoto = (req: Request<{ id: string }>, res: Response): void => {
    const userId = Number(req.params.id);
    const user = UserModel.findById(userId);
    if (!user) {
        res.status(404).json({ success: false, message: 'User not found' });
        return;
    }
    if (user.profile_photo_url?.startsWith('/uploads/profile/')) {
        const photoPath = path.resolve(__dirname, '../../uploads/profile', path.basename(user.profile_photo_url));
        if (fs.existsSync(photoPath)) fs.unlinkSync(photoPath);
    }
    res.json({ success: true, data: publicUser(UserModel.setProfilePhoto(userId, null)) });
};

// Builds the addresses row payload shared by the pickup and farm endpoints.
const readAddressBody = (body: Record<string, any>) => ({
    region: body.region,
    province: body.province,
    city_municipality: body.city_municipality,
    barangay: body.barangay,
    zip_code: body.zip_code,
    street_details: body.street_details || null,
    landmark: body.landmark || null,
    latitude: body.latitude ?? null,
    longitude: body.longitude ?? null,
});

// Sets the farm location for a farmer, which is what the explore map plots.
export const addFarmAddress = (req: Request<{ id: string }>, res: Response) => {
    try {
        const userId = parseInt(req.params.id, 10);
        if (isNaN(userId)) {
            return res.status(400).json({ success: false, message: "Invalid user ID format" });
        }
        if (userId !== authUserId(res)) {
            return res.status(403).json({ success: false, message: "You can only change your own farm address" });
        }
        if (!UserModel.findById(userId)) {
            return res.status(404).json({ success: false, message: "User not found" });
        }

        const addressId = UserModel.setFarmAddress(userId, readAddressBody(req.body));
        res.status(201).json({ success: true, data: { addressId } });
    } catch (error) {
        console.error("Error setting farm address:", error);
        res.status(500).json({ success: false, message: "Failed to set farm address" });
    }
};

export const addUserAddress = (req: Request<{ id: string }>, res: Response) => {
    try {
        const userId = parseInt(req.params.id, 10);

        if (isNaN(userId)) {
            return res.status(400).json({ error: "Invalid user ID format" });
        }
        if (userId !== authUserId(res)) {
            return res.status(403).json({ success: false, message: "You can only change your own address" });
        }
        const addressId = UserModel.setPreferredAddress(userId, readAddressBody(req.body));
        
        res.status(201).json({ 
            success: true,
            data: publicUser(UserModel.findProfile(userId)),
            message: "Address updated successfully",
            addressId
        });
    } catch (error) {
        console.error("Error setting address:", error);
        res.status(500).json({ error: "Failed to update address" });
    }
};

export const updateUserAddress = (req: Request<{ id: string }>, res: Response) => {
    const userId = Number(req.params.id);
    const addressId = Number(req.body.address_id);
    if (!Number.isInteger(userId) || !Number.isInteger(addressId)) {
        res.status(400).json({ success: false, message: 'Invalid user or address ID' });
        return;
    }
    if (userId !== authUserId(res)) {
        res.status(403).json({ success: false, message: 'You can only change your own address' });
        return;
    }
    if (!UserModel.updateAddress(userId, addressId, readAddressBody(req.body))) {
        res.status(404).json({ success: false, message: 'Address not found' });
        return;
    }
    res.json({ success: true, data: UserModel.findProfile(userId) });
};

export const choosePreferredAddress = (req: Request<{ id: string }>, res: Response) => {
    const userId = Number(req.params.id);
    const addressId = Number(req.body.address_id);
    if (!Number.isInteger(userId) || !Number.isInteger(addressId)) {
        res.status(400).json({ success: false, message: 'Invalid user or address ID' });
        return;
    }
    if (!UserModel.choosePreferredAddress(userId, addressId)) {
        res.status(404).json({ success: false, message: 'Address not found' });
        return;
    }
    res.json({ success: true, data: UserModel.findProfile(userId) });
};
import { Request, Response } from "express";
import fs from "fs";
import path from "path";
import { UserModel } from "#models/user.model";
import { createAuthToken } from "#middleware/auth.middleware";

export const getUsers = (req: Request, res: Response): void => {
    const users = UserModel.findAll();
    res.json({
        success: true,
        data: users.map(({ password_hash: _passwordHash, ...user }) => user),
    });
};

export const createUser = (req: Request, res: Response): void => {
    const { first_name, last_name, email, password, contact_number, role } = req.body;

    if (!first_name || !last_name || !email || !password || !contact_number) {
        res.status(400).json({ success: false, message: "All user fields are required" });
        return;
    }

    const normalizedEmail = email.trim().toLowerCase();
    if (UserModel.findByEmail(normalizedEmail)) {
        res.status(409).json({ success: false, message: "An account with this email already exists" });
        return;
    }

    const requestedRole = role === 'farmer' || role === 'admin' ? role : 'consumer';
    const user = UserModel.create({ first_name, last_name, email: normalizedEmail, password, contact_number, role: requestedRole });
    const { password_hash: _passwordHash, ...safeUser } = user;
    res.status(201).json({ success: true, data: { ...safeUser, access_token: createAuthToken(user.user_id) } });
};

const publicUser = (user: ReturnType<typeof UserModel.findById>, viewerId?: number) => {
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
    const user = UserModel.findById(userId);
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
    res.json({ success: true, data: publicUser(user) });
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

        const addressId = UserModel.setPreferredAddress(userId, readAddressBody(req.body));
        
        res.status(201).json({ 
            message: "Address updated successfully", 
            addressId: addressId 
        });
    } catch (error) {
        console.error("Error setting address:", error);
        res.status(500).json({ error: "Failed to update address" });
    }
};
import { Request, Response } from "express";
import { UserModel } from "#models/user.model";

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
    res.status(201).json({ success: true, data: safeUser });
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
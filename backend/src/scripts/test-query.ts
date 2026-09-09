import { UserModel } from '#models/user.model.js';

// Insert a record
const newUser = UserModel.create({
  first_name: 'Leonard',
  last_name: 'Perez',
  email: 'leoper@example.com',
  password: 'securepassword',
  contact_number: '1234567890'
});
console.log('Inserted:', newUser);

// Fetch all records
const allUsers = UserModel.findAll();
console.log('All Users:', allUsers);
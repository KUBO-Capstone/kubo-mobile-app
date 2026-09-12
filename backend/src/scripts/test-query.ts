import { UserModel } from '#models/user.model.js';

// Ad-hoc smoke check for the user model. The consumer test account
// (leoper@example.com / securepassword) is now created by `npm run seed`, so
// this script only inserts a throwaway row if it is missing.
const email = 'smoke-test@example.com';
const existing = UserModel.findByEmail(email);
const user = existing ?? UserModel.create({
  first_name: 'Smoke',
  last_name: 'Test',
  email,
  password: 'securepassword',
  contact_number: '1234567890'
});
console.log(existing ? 'Already present:' : 'Inserted:', user);

// Fetch all records
const allUsers = UserModel.findAll();
console.log('All Users:', allUsers);

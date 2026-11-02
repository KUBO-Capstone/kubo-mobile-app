import 'dotenv/config'; // must stay first: database/pg reads PG* when imported
import { pool } from '#database/pg';
import { UserModel } from '#models/user.model';

// Ad-hoc smoke check for the user model. Inserts a throwaway account
// (smoke-test@example.com) if it is missing, so it writes to whatever
// database PGHOST points at: do not run it against the shared RDS.
async function main(): Promise<void> {
  const email = 'smoke-test@example.com';
  const existing = await UserModel.findByEmail(email);
  const user = existing ?? await UserModel.create({
    first_name: 'Smoke',
    last_name: 'Test',
    email,
    password: 'securepassword',
    contact_number: '1234567890'
  });
  console.log(existing ? 'Already present:' : 'Inserted:', user);

  // Fetch all records
  const allUsers = await UserModel.findAll();
  console.log('All Users:', allUsers);
}

main().finally(() => pool.end());

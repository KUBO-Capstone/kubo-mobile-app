import fs from 'fs';
import path from 'path';

// The schema is applied with CREATE TABLE IF NOT EXISTS and there is no
// migration runner, so column renames and new constraints never reach an
// existing db.sqlite. Deleting the file first is the supported way to pick up
// a schema change in development.
//
//   npm run db:reset    (drop + recreate + reseed)
const dbPath = path.resolve(__dirname, '../database/db.sqlite');

if (fs.existsSync(dbPath)) {
    fs.unlinkSync(dbPath);
    console.log(`Removed ${dbPath}`);
} else {
    console.log('No existing database file, creating a fresh one');
}

// Importing the config recreates every table against the current DDL.
require('#config/database');
console.log('Schema recreated. Run `npm run seed` to repopulate.');

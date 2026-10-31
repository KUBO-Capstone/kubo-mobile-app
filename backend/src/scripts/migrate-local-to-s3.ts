/**
 * Copies photos saved on this machine's disk (backend/uploads/, from before
 * uploads went to S3) into the bucket, then points the database rows that
 * used them at their S3 URLs:
 *
 *   backend/uploads/products/<file>  ->  products/<file>  (product_images.image_url)
 *   backend/uploads/profile/<file>   ->  profiles/<file>  (users.profile_photo_url)
 *
 * Re-runnable: a file already in the bucket is not uploaded again, and rows
 * already on S3 URLs no longer match, so a partial run can simply be started
 * again. A file that is not a still JPG, PNG or WebP is reported and left
 * out, and so is its row. Local files are never deleted.
 *
 * Run:  npm run migrate:uploads               (uploads, then updates the database)
 *       npm run migrate:uploads -- --dry-run  (only reports what it would do)
 */
import 'dotenv/config'; // must stay first so env vars exist before other imports read them
import fs from 'fs';
import path from 'path';
import { db } from '#config/database';
import { detectImageType, mediaUrlForKey, objectExists, putImage } from '#controllers/upload.controller';

const dryRun = process.argv.includes('--dry-run');
const uploadsRoot = path.resolve(__dirname, '../../uploads');

// Each old folder, the bucket prefix its files go to, and the column that
// pointed at them. Names are fixed here, never taken from input.
const sources = [
    { folder: 'products', prefix: 'products', table: 'product_images', column: 'image_url' },
    { folder: 'profile', prefix: 'profiles', table: 'users', column: 'profile_photo_url' },
] as const;

// The names the old disk storage gave out: a UUID and the uploader's extension.
const fileNamePattern = /^[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$/;

type Move = { table: string; column: string; from: string; to: string };

async function main(): Promise<void> {
    if (dryRun) console.log('Dry run: nothing is uploaded and the database is not changed.');
    const counts = { uploaded: 0, alreadyInBucket: 0, skipped: 0, failed: 0 };
    const moves: Move[] = [];

    for (const source of sources) {
        const dir = path.join(uploadsRoot, source.folder);
        const files = fs.existsSync(dir)
            ? fs.readdirSync(dir, { withFileTypes: true }).filter((entry) => entry.isFile()).map((entry) => entry.name).sort()
            : [];
        for (const file of files) {
            const label = `uploads/${source.folder}/${file}`;
            if (!fileNamePattern.test(file)) {
                console.log(`skip     ${label}: not a name the server gave out`);
                counts.skipped++;
                continue;
            }
            const data = fs.readFileSync(path.join(dir, file));
            const type = detectImageType(data);
            if (!type) {
                console.log(`skip     ${label}: not a still JPG, PNG or WebP`);
                counts.skipped++;
                continue;
            }
            const key = `${source.prefix}/${file}`;
            try {
                if (await objectExists(key)) {
                    console.log(`present  ${label} -> ${key}`);
                    counts.alreadyInBucket++;
                } else {
                    if (!dryRun) await putImage(key, data, type);
                    console.log(`${dryRun ? 'would up' : 'uploaded'} ${label} -> ${key}`);
                    counts.uploaded++;
                }
            } catch (error) {
                console.error(`FAILED   ${label}:`, error);
                counts.failed++;
                continue;
            }
            moves.push({ table: source.table, column: source.column, from: `/uploads/${source.folder}/${file}`, to: mediaUrlForKey(key) });
        }
    }

    // Rows only move once their photo is safely in the bucket, all in one
    // transaction so the database is never half switched over.
    let rows = 0;
    if (dryRun) {
        for (const move of moves) {
            rows += (db.prepare(`SELECT COUNT(*) AS n FROM ${move.table} WHERE ${move.column} = ?`).get(move.from) as { n: number }).n;
        }
    } else {
        db.transaction(() => {
            for (const move of moves) {
                rows += db.prepare(`UPDATE ${move.table} SET ${move.column} = ? WHERE ${move.column} = ?`).run(move.to, move.from).changes;
            }
        })();
    }

    // Anything still on an /uploads/ path will not load: the server no
    // longer serves that folder.
    const leftovers = sources.flatMap((source) =>
        (db.prepare(`SELECT ${source.column} AS url FROM ${source.table} WHERE ${source.column} LIKE '/uploads/%'`).all() as { url: string }[])
            .map((row) => `${source.table}.${source.column} = ${row.url}`));

    console.log(
        `Done${dryRun ? ' (dry run)' : ''}: ${counts.uploaded} ${dryRun ? 'to upload' : 'uploaded'}, ` +
        `${counts.alreadyInBucket} already in the bucket, ${counts.skipped} skipped, ${counts.failed} failed; ` +
        `${rows} database row${rows === 1 ? '' : 's'} ${dryRun ? 'to point' : 'pointed'} at S3.`,
    );
    if (leftovers.length > 0 && !dryRun) {
        console.log(`${leftovers.length} row(s) still use a local path and will not show a photo:`);
        for (const leftover of leftovers) console.log(`  ${leftover}`);
    }
    if (counts.failed > 0) process.exitCode = 1;
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});

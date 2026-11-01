# Media storage (S3)

Listing photos and profile pictures are stored in Amazon S3. The backend
keeps no photos on disk and no longer serves `/uploads/`, so **photo upload
and display do not work without the S3 settings below.**

## How it works

| | Bucket key | Uploaded by |
|---|---|---|
| Listing photos | `products/<uuid>.<ext>` | `POST /api/products/images` |
| Profile pictures | `profiles/<uuid>.<ext>` | `POST /api/users/:id/profile/photo` |

- Uploads are held in memory, checked by their bytes (still JPEG, PNG or
  WebP only; the file name and MIME type the client sends are ignored), then
  written with `PutObject`. Code: `backend/src/controllers/upload.controller.ts`.
- The database stores the plain S3 URL,
  `https://<bucket>.s3.<region>.amazonaws.com/<key>`
  (`product_images.image_url`, `users.profile_photo_url`).
- The bucket stays private. Before any JSON response is sent, each stored URL
  in it is replaced with one the app can load
  (`backend/src/middleware/media.middleware.ts`):
  - **`MEDIA_BASE_URL` set** (e.g. CloudFront): `<MEDIA_BASE_URL>/<key>`.
  - **Not set**: a presigned `GetObject` link. It stays the same for a whole
    UTC day (so the app's image cache keeps working) and is valid for at least
    six more days.
- When the app sends a photo URL back (editing a listing), any of those forms
  is accepted and turned back into the stored URL.

## Configuration (`backend/.env`)

| Variable | Required | |
|---|---|---|
| `AWS_REGION` | yes | Region of the bucket, e.g. `ap-southeast-1`. |
| `S3_BUCKET` | yes | Bucket name. |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | locally | On AWS (EC2/ECS) use the instance or task role instead. |
| `MEDIA_BASE_URL` | no | Public base URL for photos, without a trailing slash. |

### IAM permissions for the app

`HeadObject` and presigned links both use `s3:GetObject`; `s3:ListBucket` is
not needed.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
    "Resource": [
      "arn:aws:s3:::<bucket>/products/*",
      "arn:aws:s3:::<bucket>/profiles/*"
    ]
  }]
}
```

### Presigned links or CloudFront

Presigned links need no bucket changes, which suits local development with an
IAM user's access keys. A link signed with temporary credentials (an IAM role)
stops working when those credentials expire, typically within hours, so for a
deployed server put CloudFront in front of the bucket with Origin Access
Control and set `MEDIA_BASE_URL` to the distribution's URL. Nothing in the
database changes when you switch.

The mobile app needs no CORS rules on the bucket. A Flutter **web** build
would.

## Moving photos from an older install

Photos saved before this change sit in `backend/uploads/products/` and
`backend/uploads/profile/`. Copy them to the bucket and point the database at
them:

```
cd backend
npm run migrate:uploads -- --dry-run   # report only
npm run migrate:uploads
```

The script (`backend/src/scripts/migrate-local-to-s3.ts`) is safe to rerun:
files already in the bucket are not uploaded again, and rows already on S3
URLs are left alone. Files that are not a still JPG, PNG or WebP are skipped
and listed, as are rows that still point at a local path afterwards. It never
deletes local files; remove `backend/uploads/` yourself once the app shows
every photo.

## RDS schema note

`backend/src/database/migrations/001_init.sql` (the RDS schema) stores object
keys (`profile_photo_key`, `image_key`) rather than URLs. When the data moves
to RDS, the key is the stored URL with the
`https://<bucket>.s3.<region>.amazonaws.com/` prefix removed.

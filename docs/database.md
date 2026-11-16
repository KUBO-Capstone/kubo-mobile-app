# Database (PostgreSQL on Supabase)

The backend stores everything except chat messages in PostgreSQL on Supabase.
Chat messages are in DynamoDB (`backend/src/models/message.model.ts`) and
photos in S3 ([media_storage.md](media_storage.md)).

- Connection pool: `backend/src/database/pg.ts`. Every model queries through it.
- Schema: `backend/src/database/migrations/*.sql`, applied in file-name order
  by `npm run db:migrate`, which records each file in `schema_migrations`.

## Configuration (`backend/.env`)

| Variable | |
|---|---|
| `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD` | The Supabase host and login. In the dashboard, click **Connect** and choose **Session pooler**. |
| `PGSSLROOTCERT` | Set to `certs/supabase-ca.crt`, and run the backend from `backend/`. Without it, the backend expects the old RDS certificate and the connection fails. |
| `PGSSLMODE` | Leave unset for Supabase. Set to `disable` only for a Postgres on your own machine. |

Use the session pooler (port 5432). The transaction pooler (port 6543) does
not support the session-level lock that `npm run db:migrate` takes, and the
direct connection needs IPv6 or the paid IPv4 add-on.

`npx tsx src/scripts/test-connections.ts` checks the database, DynamoDB and S3
in one go. Its database line still says "RDS Postgres", but it checks whatever
`PGHOST` points at.

## Supabase project

- The project is `kubo-dev`, running Postgres 17.
- The free plan allows 500 MB per project and pauses a project after about a
  week of low activity. If the backend suddenly cannot connect, check whether
  the project is paused and restore it from the dashboard.
- The Data API is turned off. The backend does not use it: it connects
  directly as `postgres`.

## Commands (run in `backend/`)

| Command | |
|---|---|
| `npm run db:migrate` | Applies the migrations the database does not have yet. Safe to run again. |
| `npm run seed` | Adds the bagsakan centers and the Market Watch reference prices. No accounts or listings: those come from the app. Safe to run again. |
| `npm run db:reset -- --yes` | **Deletes every row**, migrates, then seeds. Without `--yes` it only tells you which database it would wipe. On the shared Supabase database this wipes everyone's data. |

The server checks on startup that every migration has been applied. If one
is missing it does not start, and tells you to run `npm run db:migrate`.

## Changing the schema

Add a new numbered file, for example `005_<what>.sql`. Never edit a file that
has already been applied. Wrap the file in `BEGIN; ... COMMIT;` and make it
safe to re-run (`IF NOT EXISTS`, guarded `DO` blocks), like the existing ones.
Then run `npm run db:migrate`, and tell the team to run it too.

## What the code relies on

- **Return types.** `numeric` and `bigint` (prices, quantities, `COUNT`) come
  back as JS numbers. `date` comes back as `'YYYY-MM-DD'`, and `timestamptz`
  as an ISO string. `jsonb` (`users.profile_privacy`, `reviews.tags`) comes
  back already parsed. All of this is set up in `pg.ts`.
- **Requests run concurrently.** SQLite ran one request at a time, so a
  "check, then write" in a controller could not be interrupted. On Postgres
  it can, so the writes guard themselves:
  - Status changes only apply from the status that was checked. The model
    returns `undefined` if another request got there first, and the
    controller answers 409.
  - Unique indexes back the "already exists" checks: one thread per buyer
    and listing, one open offer, one order per accepted offer, one review per
    side, one account per email. A violation also answers 409.
  - Stock is only taken if it is still there (see below).
- **Transactions.** Multi-step writes go through `withTransaction` in `pg.ts`.

## Stock and "sold out"

`products.available_quantity` is what a buyer can still get, and a listing
reads `out of stock` only when that reaches zero (or the seller marks it by
hand).

- **Accepting an offer takes its quantity off the listing**, in the same
  transaction as the accept, and records it in
  `negotiations.reserved_quantity`. If the listing has less left than the
  offer, the accept is refused (409) and the seller can counter with less.
- **Placing the order** does not take stock again: it clears
  `reserved_quantity`, and from then on the order holds the stock.
- **Stock comes back** when an accepted offer is cancelled before it is
  ordered (`PATCH /negotiations/:id` with `action: "cancel"`, either side),
  or when a pending order is cancelled. A listing that was sold out only
  because nothing was left becomes `available` again.
- Offers accepted before migration 005 have `reserved_quantity` NULL; their
  stock is taken when the order is placed, as it used to be.

## Listing locations and the map

A listing shows its seller's farm address (`farmer_profiles`) when they have
one, and otherwise the town they registered with. On the map a farm address
is plotted at its own coordinates; everyone else is plotted at their town.
Town points are looked up once from OpenStreetMap by
`backend/src/services/geocoding.service.ts` and kept in `place_coordinates`.
Only the town and province names are sent. The lookup runs in the background
on server start and whenever a listing or an address may have added a town;
`GEOCODING_ENABLED=false` in `backend/.env` turns it off.

## Legacy SQLite files

`backend/src/config/database.ts` and `backend/src/database/db.sqlite` are the
old SQLite setup. The server no longer uses them. Only two one-off scripts
still read the SQLite file: `migrate:uploads` (local photos to S3) and
`migrate:messages` (old chat messages to DynamoDB).

## AWS RDS (previous setup, not in use)

The database ran on AWS RDS until November 2026, then moved to Supabase to
avoid RDS costs during development. The details below are kept for reference
in case the project moves back. `backend/certs/global-bundle.pem` and the
default certificate path in `backend/src/database/pg.ts` come from this setup.

| Variable | |
|---|---|
| `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD` | The RDS endpoint and login. |
| `PGSSLROOTCERT` | Optional. Path to the RDS CA bundle; defaults to `backend/certs/global-bundle.pem`. |
| `PGSSLMODE` | Leave unset for RDS. Set to `disable` only for a Postgres on your own machine. |

Your IP has to be allowed by the RDS security group (inbound TCP 5432) for
the connection to work. `npx tsx src/scripts/test-connections.ts` checks RDS,
DynamoDB and S3 in one go.

`npm run db:reset -- --yes` on the shared RDS wipes everyone's data.

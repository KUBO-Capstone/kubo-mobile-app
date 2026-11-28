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

## Offers, orders and the closed deal

An offer carries its full terms: price, quantity, and how the produce
changes hands (`negotiations.delivery_method` with `drop_off_center_id` or
`courier_name`). The buyer can only pick centers and couriers the seller
supports (`seller_bagsakan_centers`, `seller_couriers`; an empty list means
"any"). A seller can optionally give one listing its own choices
(`products.custom_fulfillment` with `product_bagsakan_centers` /
`product_couriers`, migration 007); that listing then uses them instead,
and the profile's are left as they are. A seller's counter can change any of the terms, including moving to
a farther center at a higher price, and replaces the offer on the table.
A seller's decline can carry a `decline_reason` the buyer sees in the chat.

Accepting an offer locks those terms and creates the order in the same
transaction (status `pending`, shown as "In progress"); there is no
separate "arrange pickup" step. Offers from before migration 006 have no
handover terms and keep the old flow: accepted, then the buyer places the
order.

When the seller hands the order over (to the courier, or at the center),
the order records the tracking number, optional photos of the produce
(`orders.handover_photos`, keys under `handovers/` in S3) and the time
(`orders.shipped_at`), migration 008. Both sides see them on the order.

The deal counts as closed when the buyer confirms receipt (order
`delivered`). That is when both sides see the "deal closed" screen
(`celebration_pending` in the conversation) and can review each other.

## Stock and "sold out"

`products.available_quantity` is what a buyer can still get, and a listing
reads `out of stock` only when that reaches zero (or the seller marks it by
hand).

- **Accepting an offer takes its quantity off the listing**, in the same
  transaction as the accept. If the listing has less left than the offer,
  the accept is refused (409) and the seller can counter with less. The
  order created at acceptance holds that stock. (An offer from before
  migration 006 records it in `negotiations.reserved_quantity` instead.)
- **Placing an older offer's order** does not take stock again: it clears
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

## Reports

Two tables, for two different things:

- `reports`: app feedback and bug reports from the drawer's Report page
  (`POST /reports`).
- `moderation_reports` (migration 010): a listing or an account reported
  from the kebab menu on the listing page or a profile
  (`POST /reports/listings/:id` and `POST /reports/users/:id`, body
  `{ "reason": "..." }`). `product_id` is set for a listing report and NULL
  for a profile report. `reported_user_id` is always set: for a listing it is
  the seller. `status` starts as `open`. Nobody can report themselves or
  their own listing, and a user can have only one open report per listing
  and per profile (a second one answers 409). Nothing in the app reads these
  yet: review them in the Supabase table editor.

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

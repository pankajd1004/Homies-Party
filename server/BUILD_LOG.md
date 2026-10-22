# Build Log

## Step 1 - Project inspection
- **What was done:** Inspected the overall repository structure, Flutter application code in `lib/`, game modules, `pubspec.yaml`, toolchains, and verified whether any backend service existed.
- **What changed in the project:** Nothing changed (inspection only).
- **Findings:**
  - 5 games found (Dots & Boxes, Carrom, Pen Fight, Air Hockey, Ludo).
  - Flutter without Flame engine (built using standard Flutter widgets, CustomPainter, and AnimationController/Ticker physics).
  - No backend service was present.
  - Node, npm, and Git are installed on the machine.

## Step 2 - Backend foundation
- **What was done:** Initialized and set up a Node.js + TypeScript backend inside the `server/` directory. Created the following files:
  - `server/package.json` - Project metadata, scripts (`dev`, `build`, `typecheck`, `start`, `migrate:up`, `migrate:down`), and dependencies (`fastify`, `pg`, `dotenv`, `tsx`, `typescript`, `node-pg-migrate`).
  - `server/package-lock.json` - Locked dependency tree.
  - `server/tsconfig.json` - TypeScript compiler configuration.
  - `server/.gitignore` - Git ignore rules for `node_modules`, `dist`, and `.env`.
  - `server/.env.example` - Environment variable template defining `PORT` and `DATABASE_URL`.
  - `server/src/server.ts` - Fastify server setup exposing `/health` and `/health/db` endpoints.
  - `server/src/db.ts` - PostgreSQL client connection pool using `pg`.
  - `server/migrations/1792611799879_initial-tables.sql` - Database migration script for initial schema tables.
- **What changed in the project:**
  - The standalone backend service now runs successfully.
  - Fastify server starts and listens on `http://0.0.0.0:3000`.
  - `GET /health` returns `{ "status": "ok", "app": "Homies Party Backend" }`.
  - `GET /health/db` provides database connectivity checks.
  - TypeScript compilation and type checking pass without errors.
- **How to test:**
  1. Open a terminal and navigate to `server/`:
     ```bash
     cd server
     ```
  2. Install dependencies (if not already installed):
     ```bash
     npm install
     ```
  3. Run TypeScript type check:
     ```bash
     npm run typecheck
     ```
  4. Start the development server:
     ```bash
     npm run dev
     ```
  5. In another terminal window or browser, test the health endpoint:
     ```bash
     curl http://localhost:3000/health
     ```
     Expected response:
     ```json
     {"status":"ok","app":"Homies Party Backend"}
     ```

## Step 3 - Database setup
- **What was done:**
  - Integrated PostgreSQL using the `pg` client library and `node-pg-migrate` for SQL-based migrations.
  - Implemented `server/src/db.ts` to create and export a shared PostgreSQL connection `Pool` using `DATABASE_URL` loaded from `.env` via `dotenv`.
  - Created migration file `server/migrations/001_initial_tables.sql` establishing 3 relational tables:
    - `users` (id uuid pk, firebase_uid text unique nullable, nickname text, avatar text, created_at)
    - `rooms` (id uuid pk, code text unique, host_user_id fk users, status text default 'lobby', max_players int, created_at)
    - `room_players` (room_id fk, user_id fk, is_ready bool default false, joined_at, primary key (room_id, user_id))
  - Configured npm scripts in `server/package.json`:
    - `npm run migrate:up`: Executes pending database migrations.
    - `npm run migrate:down`: Reverts applied database migrations.
  - Added route `GET /health/db` in `server/src/server.ts` that executes `SELECT 1` on the pool and returns `{ "db": "ok" }` on success or HTTP 500 with error details on failure.
  - Configured `server/.env.example` with `DATABASE_URL=postgresql://postgres:PASSWORD@localhost:5432/homies_party`.
- **What changed in the project:**
  - The backend server can now connect to PostgreSQL and query the database.
  - Database schema can now be tracked, applied, and rolled back deterministically using migration scripts.
  - Relational schema for players, game rooms, and lobby participant states is provisioned in the database.
  - Real-time DB connectivity can be monitored via the `GET /health/db` endpoint.
- **How to test:**
  1. Navigate to `server/`:
     ```bash
     cd server
     ```
  2. Verify TypeScript types:
     ```bash
     npm run typecheck
     ```
  3. Run database migrations:
     ```bash
     npm run migrate:up
     ```
  4. Start the dev server:
     ```bash
     npm run dev
     ```
  5. Test endpoints in a browser or terminal:
     - Health route:
       ```bash
       curl http://localhost:3000/health
       ```
       Returns:
       ```json
       {"status":"ok","app":"Homies Party Backend"}
       ```
     - Database health route:
       ```bash
       curl http://localhost:3000/health/db
       ```
       Returns:
       ```json
       {"db":"ok"}
       ```
  6. (Optional) Test rolling back migrations:
     ```bash
     npm run migrate:down
     ```

## Step 4 - Guest login (Firebase)
- **What was done:**
  - Added `secrets/` to `server/.gitignore` to protect service account keys and secrets.
  - Installed `firebase-admin` package for server-side token authentication.
  - Created `server/src/firebase.ts` to initialize Firebase Admin SDK using application default credentials (`GOOGLE_APPLICATION_CREDENTIALS`).
  - Created `server/src/auth.ts` providing an `authenticate` preHandler hook that validates the `Authorization: Bearer <token>` header with Firebase and returns HTTP 401 on missing or invalid tokens.
  - Added Fastify routes in `server/src/server.ts`:
    - `POST /v1/auth/guest`: Looks up the user by `firebase_uid`. If not found, creates a new user profile with nickname format `Guest<4 digits>` and returns the user object.
    - `GET /v1/me`: Returns the authenticated user's profile.
    - `PATCH /v1/me`: Allows updating the user's `nickname` (2-20 characters) and `avatar` (max 30 characters), returning HTTP 400 for invalid inputs.
  - Used parameterized SQL queries (`$1`, `$2`, etc.) across all database operations.
  - Redacted the `authorization` header in Fastify logging so tokens are never logged.
  - Added automated test script `server/scripts/test-guest.ts` and configured npm script `npm run test:guest`.
- **What changed in the project:**
  - Clients can now authenticate using Firebase ID tokens.
  - Anonymous/guest players can sign in and automatically receive a database profile.
  - Authenticated players can fetch and update their profile (`nickname` and `avatar`).
  - Protected endpoints reject unauthenticated or malformed requests with HTTP 401.
- **How to test:**
  1. Navigate to `server/`:
     ```bash
     cd server
     ```
  2. Run TypeScript check:
     ```bash
     npm run typecheck
     ```
  3. Start the dev server (if not already running):
     ```bash
     npm run dev
     ```
  4. Run the guest login automated test suite:
     ```bash
     npm run test:guest
     ```
     Expected output:
     ```
     PASS: POST /v1/auth/guest created/retrieved guest user
     PASS: GET /v1/me returned profile successfully
     PASS: PATCH /v1/me updated nickname successfully
     PASS: GET /v1/me without token was rejected with 401 Unauthorized
     ```
  5. Test unauthorized access manually using curl:
     ```bash
     curl http://localhost:3000/v1/me
     ```
     Returns HTTP 401:
     ```json
     {"error":"Unauthorized","message":"Missing or invalid Authorization header. Format must be Bearer <token>."}
     ```


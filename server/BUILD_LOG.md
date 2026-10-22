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

## Step 5 - Online rooms
- **What was done:**
  - Implemented online room management in `server/src/rooms.ts` using existing database tables (`users`, `rooms`, `room_players`), connection pool, and `authenticate` preHandler.
  - Added 6-character room code generation using base32 character set `[A-Z2-9]` excluding ambiguous characters (`O`, `I`, `0`, `1`), with collision retry logic.
  - Implemented endpoints:
    - `POST /v1/rooms`: Creates a new room with configurable `maxPlayers` (2-4, default 4), sets status to `'lobby'`, adds the creator to `room_players` as host, and returns the room with players.
    - `POST /v1/rooms/join`: Case-insensitive room code join. Uses PostgreSQL row locking (`SELECT ... FOR UPDATE`) in a database transaction to prevent overfilling seats concurrently. Returns existing room if the user is already a member, 404 if not found, 409 if full or not in `'lobby'` status.
    - `GET /v1/rooms/:code`: Returns room details and player list (nickname, avatar, isReady, isHost). Accessible to room members only (403 for non-members).
    - `POST /v1/rooms/:code/ready`: Allows room members to toggle ready status (`{"ready": true/false}`).
    - `POST /v1/rooms/:code/leave`: Removes member from room. If host leaves, assigns the earliest-joined remaining player as host. If room becomes empty, deletes the room.
    - `POST /v1/rooms/:code/start`: Allows host to start the game. Requires at least 2 players and all players to be ready; updates status to `'playing'`.
  - Added strict input validation (returns HTTP 400 on invalid payload or params) and checked that logged-in Firebase users exist in the `users` table (HTTP 404 with clear message).
  - Ensured all database queries use parameterized SQL variables (`$1`, `$2`, etc.) and no tokens are logged.
  - Added automated test suite `server/scripts/test-rooms.ts` and configured npm script `"test:rooms": "tsx scripts/test-rooms.ts"`.
- **What changed in the project:**
  - The backend server can now host and orchestrate multiplayer game lobbies and rooms entirely through REST endpoints.
  - Players can create private rooms with short, human-friendly 6-character codes.
  - Players can join lobbies, toggle their readiness, and hosts can start games once all participants are ready.
  - Lobby membership is protected with transaction safety, seat limits, and member-only room visibility.
- **How to test:**
  1. Navigate to `server/`:
     ```bash
     cd server
     ```
  2. Run TypeScript compiler check:
     ```bash
     npm run typecheck
     ```
  3. Start the dev server (if not already running):
     ```bash
     npm run dev
     ```
  4. Run the automated rooms test suite:
     ```bash
     npm run test:rooms
     ```
     Real output:
     ```
     PASS: Registered guest users (User A, User B, User C)
     PASS: User A created room with code 'HVM99E' (status: lobby, creator is host)
     PASS: User B joined the room with case-insensitive code (2 players now in room)
     PASS: User A marked ready
     PASS: User B marked ready (both players ready)
     PASS: Host started the game successfully (status is playing)
     PASS: Third guest trying to join started room received 409 Conflict
     PASS: Non-member reading the room received 403 Forbidden
     PASS: Member reading the room returned room details and player list successfully
     PASS: Logged-in Firebase user without row in users received 404
     PASS: Invalid maxPlayers (5) rejected with 400 Bad Request
     PASS: Empty room code on join rejected with 400 Bad Request
     PASS: Host left room; earliest remaining player (User B) became new host
     PASS: Last player left room; room was deleted because it became empty
     ```



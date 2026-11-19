# TrashLab

TrashLab specifics for the **verify** skill. The repo's `AGENTS.md` says to run the app, browser, or device flow only when the user asks or the change cannot be judged from code and tests. Invoking `/verify` or `/build` is that ask. Prefer `just` recipes, and never run `tsc` or `bun check` directly. Typecheck each touched project once with `just lint-file <path>`. It needs `bun check`, which ships in Bun 1.4.3 and later. If `bun --version` is older, ask the user to run `brew upgrade bun` instead of upgrading it yourself, and report the typecheck as not run. The repo's `qa-verify` skill posts a before-and-after QA table to the PR and has its own approval gates, so run it only when the user invokes it. This file is the lane for `/verify` and `/build`.

## Ports per worktree

Every worktree has its own ports and database, recorded in `<worktree>/.workspace` (`apiPort`, `webPort`, `sitesPort`, `inngestPort`, `dbName`, `sessionCookieName`). Read them before you drive anything, because the main checkout is not always on 3000 and 3010.

- `cat .workspace`, or `grep -E '^(PORT|VITE_WEB_PORT|SESSION_COOKIE_NAME)=' .env.local`, or `just ws status`.
- `just dev` runs `just workspace check-ports` first, which moves any taken port and rewrites `.workspace` and `.env.local`. Re-read the ports after it starts. It prints `Using ports - API: …`.
- A new worktree gets its full setup from `scripts/supacode/setup.sh`: `pnpm install`, then `just workspace init --here --with-db`, which restores a database snapshot of about 17 GB. A worktree with dependencies only cannot run the app or database tests.
- Start the full stack with `just dev`. Start one side with `just api-dev` or `just web-dev`. If the user already runs `just dev`, reuse it and do not stop it at cleanup.

## Database

- Apply migrations with `just migrate dev`. It ensures DB roles, runs dbmate up, and syncs Prisma only when migrations were applied. `just migrate status` lists pending ones.
- Drift check: `just ci-check-db-migration-run-clean`. It prepares the e2e database, runs `just migrate dev --skip-prisma-generate`, and fails if git shows changed or new files afterward. Run it when a change touches migrations or the Prisma schema.
- Read-only queries: local dev has no read-only role, so keep every query a `SELECT`. Connect with `psql "<DATABASE_URL from .env.local>"`, reading the value from the file without sourcing `.env` (the URL is `postgresql://postgres:postgres@localhost:54322/<dbName>`).

## Login

`just login-as [email|tenant-uuid] [--app web|admin|driver] [--token] [--json]` (script at `packages/api/src/scripts/dev-only/login-as.ts`).

- Default output is a one-time OTP link on the web host, valid for 10 minutes. Open it with `agent-browser` to sign in.
- `--token` needs the local API running and prints a session token. With `--json` it also returns `sessionCookieName` and `apiOrigin`.
- `just dev` already runs `just login-as --startup --app web` once.

## API

- tRPC is mounted at `http://localhost:<apiPort>/api/trpc` (superjson, batching on) and `/api/trpc-no-superjson`. Procedures are named by `.path('domain.x.y')` in `packages/api/src/domains/`.
- Auth is the session cookie or a header named after `SESSION_COOKIE_NAME` (`tl-session` in the main workspace, `tl-session-<name>` in others). Get a token from `just login-as <email> --token --json`.
- Example: `curl -s -H "$SESSION_COOKIE_NAME: <token>" "http://localhost:$PORT/api/trpc/<path>?input=<url-encoded {\"json\":...}>"`.
- The API log is `packages/api/.dev.log`. It is written only when `NEXT_PUBLIC_TRASHLAB_ENV=local`, emptied on every API start, and defaults to `warn` level (`LOG_LEVEL` raises it). Read the request with `grep -E '\[TRPC\]|error' packages/api/.dev.log`. tRPC failures log as `[TRPC] Request error` with a `requestId`.

## Mobile

- Driver app id `com.trashlab.driver` (`apps/mobileapp`), admin app id `com.trashlab.admin` (`apps/mobileadmin`), on both iOS and Android.
- iOS: `just mobile driver ios` builds for the simulator. With the app already installed, `just mobile driver start` and press `i`. Drive it with `serve-sim`. The simulator build has no barcode or MLKit support.
- Android: `just mobile driver android` builds, installs, and launches through `expo run:android`, and `device <id>` picks the emulator. Metro is on 8081. The emulator reaches the host only through `adb -s "$S" reverse tcp:8081 tcp:8081` and `adb -s "$S" reverse tcp:<apiPort> tcp:<apiPort>`. Drive it with the Android lane in the **verify** skill (serve-avd, with raw `adb` as the fallback), including login and starting the day. After the day is started, save an emulator snapshot so later attempts can reset to it. Do not use Maestro flows.
- Slim flags for both apps (see "Slim iOS simulators" in the **verify** skill): they use push notifications, the photo picker and media library, and contacts, so pass `--except photos,pim --keep com.apple.apsd` and confirm with `simslim doctor <udid> --requires push,photos,contacts`.
- Mobile admin's More menu and the driver app's admin screens load viteapp in a WebView. To check a viteapp change as it looks there without a native build, run `localStorage.setItem('isInWebview', 'true')` on the app origin, reload, and use a phone viewport minus the native header (about 390x740). That drops the sidebar and nav like the real WebView does. Native behavior such as downloads and outside links still needs a device, so report it as unverified.
- Filter logcat with `--pid="$(adb -s "$S" shell pidof -s com.trashlab.driver)"`.

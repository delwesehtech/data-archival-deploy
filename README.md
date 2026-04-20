# data-archival-deploy

Config-only deployment repo for `data-archival`.

## Quick start

```bash
cd data-archival-deploy
cp .env.example .env
# edit .env: SERVER_DEPLOY_DIR (e.g. servers/crick), COMPOSE_PROJECT_NAME, paths, IMAGE_*, SERVER_NAME, …
docker compose --env-file .env -f docker-compose.yml up -d visibility
```

To target a different server folder on the same machine, change `SERVER_DEPLOY_DIR` (and usually `COMPOSE_PROJECT_NAME`, paths, and labels) in `.env`, then run Compose again from the repo root.

Use `./aliases.sh` from the repo root for shortcuts (`restart_visibility`, dry-run cleanup, etc.).

This repo intentionally keeps only:
- one **shared** `docker-compose.yml` at the repo root (same stack for every server)
- a single **`.env`** at the repo root next to Compose (gitignored; copy from `.env.example`) — set `SERVER_DEPLOY_DIR` to point at the active server folder
- per-server folders under `servers/<name>/` with **`policy/`** and **`logs/`** only
- `.env.example` next to `docker-compose.yml` (tracked template for `.env`)
- small deploy helper scripts (`aliases.sh`, `scripts/cron-archival.sh`)
- root `VERSION` (last released deploy tag; used by `scripts/tag-and-push.sh`)

Application code and image build logic stay in the `data-archival` repo.

## Layout

- `docker-compose.yml` — shared services (`archival`, `cleanup_scratch`, `cleanup_archive`, `visibility`)
- `.env` (repo root, not tracked) — `SERVER_DEPLOY_DIR`, `COMPOSE_PROJECT_NAME`, image tag, bind-mount paths, UI labels
- `servers/crick/` — example server: `policy/`, `logs/`
- `servers/<server>/` — add a folder per host; point root `.env` at it via `SERVER_DEPLOY_DIR`

## Deploy model

1. Build and push image from `data-archival` tagged as:
   - `...:<git-sha>`
   - `...:latest`
2. Update `IMAGE_TAG=<git-sha>` in the repo root `.env` on that host.
3. On the server, from this **repo root**, run Compose (see Quick start).

## Release tags (main only)

From the **repo root**, on branch **`main`** (merge your work first):

```bash
./scripts/tag-and-push.sh
```

This script:

1. Refuses to run unless the current branch is **`main`**.
2. Pushes **`main`** to **`origin`** (override with **`GIT_REMOTE`**).
3. Reads **`VERSION`** (format **`v1.05`**), creates the next tag (e.g. **`v1.06`**), pushes that tag.
4. Writes the new value into **`VERSION`** locally — **commit and push** that change to `main` if you want it tracked.

If your last git tag is already ahead of **`VERSION`**, edit **`VERSION`** to match before running so the next tag does not collide.

## Local helpers (`aliases.sh`)

From the repo root, run **`./aliases.sh`** (executable). That starts an interactive **bash** with helpers loaded; type **`avd_help`** for the list. Type **`exit`** to leave that shell. To load into your **current** shell instead: `source ./aliases.sh`.

## Cron (optional)

Cron must run commands from **this repo root** so `--env-file .env` and `docker-compose.yml` resolve. Put `docker` on `PATH` or use absolute paths.

**Scratch cleanup (dry-run scan)** — same as compose defaults:

```bash
0 3 * * *  cd /path/to/data-archival-deploy && docker compose --env-file .env -f docker-compose.yml run --rm cleanup_scratch
```

**Scratch cleanup (execute deletes)** — append CLI args after the service name:

```bash
0 4 * * 0  cd /path/to/data-archival-deploy && docker compose --env-file .env -f docker-compose.yml run --rm cleanup_scratch --execute --log-dir /app/logs
```

**Archive drive cleanup** — use service `cleanup_archive` instead of `cleanup_scratch`.

**Archival (scratch → archive)** — wrapper that mirrors the old app-repo script (`ARCHIVAL_EXECUTE`, `ARCHIVAL_SCOPE`):

```bash
0 2 * * 0  /path/to/data-archival-deploy/scripts/cron-archival.sh >> /path/to/data-archival-deploy/servers/<name>/logs/cron/archival.log 2>&1
```

There is no in-repo scheduler beyond host cron; add only the jobs you need.

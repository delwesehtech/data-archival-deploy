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
- small deploy helper scripts (`aliases.sh`, `scripts/cron-archival.sh`, `scripts/release-with-app.sh`, …)
- root `VERSION` (last released deploy tag; used by release / tag scripts)

Application code and image build logic stay in the `data-archival` repo.

## Layout

- `docker-compose.yml` — shared services (`archival`, `cleanup_scratch`, `cleanup_archive`, `visibility`)
- `.env` (repo root, not tracked) — `SERVER_DEPLOY_DIR`, `COMPOSE_PROJECT_NAME`, image tag, bind-mount paths, UI labels
- `servers/crick/` — example server: `policy/`, `logs/`
- `servers/<server>/` — add a folder per host; point root `.env` at it via `SERVER_DEPLOY_DIR`

## Deploy model

1. Build and push image from `data-archival` (see **Release** below), tagged with the same semver as **`VERSION`** (e.g. `v1.08`) and usually `:latest`.
2. Update **`IMAGE_TAG`** in the repo root **`.env`** on each host to that tag (or `:latest` if you track that).
3. On the server, from this **repo root**, run Compose (see Quick start).

## Release (app image + both git tags)

Use one flow so the **app** image tag and **both** repos’ git tags stay the same semver (do **not** run `tag-and-push.sh` right after `build-and-push.sh` without syncing — it would bump deploy **`VERSION`** again).

**Recommended — from `data-archival-deploy` on `main`:**

```bash
export DATA_ARCHIVAL_ROOT=/path/to/data-archival   # optional if ../data-archival exists
./scripts/release-with-app.sh amd64                 # or arm64 / both
```

This runs **`data-archival/scripts/build-and-push.sh`** (bumps app **`VERSION`**, creates and pushes the **app** git tag, buildx-push **`IMAGE_REPO:${tag}`** and **`:latest`**), copies the new tag into deploy **`VERSION`**, commits **`VERSION`** on deploy **`main`** if it changed, then **`scripts/push-main-and-tag.sh`** to push deploy **`main`** and the **same** annotated tag.

Then **commit and push** the app repo’s **`VERSION`** on **`main`** if you track it (the script prints a reminder).

**Env:** `DATA_ARCHIVAL_ROOT`, `GIT_REMOTE` (default `origin`); **`IMAGE_REPO`** is read by `build-and-push.sh` in the app repo.

### Deploy-only tag bump

If you only need a new **deploy** repo tag (no new image), from the repo root on **`main`**:

```bash
./scripts/tag-and-push.sh
```

That increments **`VERSION`**, pushes **`main`**, creates the next tag, pushes the tag, then updates **`VERSION`** on disk — **commit** that file if you track it.

**Lower-level:** `scripts/push-main-and-tag.sh [v1.08]` pushes **`main`** and creates the annotated tag with **no** bump (used by the scripts above).

If your last git tag is already ahead of **`VERSION`**, edit **`VERSION`** to match before running `tag-and-push.sh` so the next tag does not collide.

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

# data-archival-deploy

Config-only deployment repo for `data-archival`.

This repo intentionally keeps only:
- per-server `docker-compose.yml`
- `policy/` (YAML policies mounted at `/policy` in containers)
- `.env` templates
- small deploy helper scripts
- root `VERSION` (last released deploy tag; used by `scripts/tag-and-push.sh`)

Application code and image build logic stay in the `data-archival` repo.

## Layout

- `servers/crick/` - first server deployment config
- `servers/<server>/` - clone from `crick` for each additional server

## Deploy model

1. Build and push image from `data-archival` tagged as:
   - `...:<git-sha>`
   - `...:latest`
2. Update `IMAGE_TAG=<git-sha>` in target environment `.env`.
3. Run deploy script on the server from that environment folder.

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

## Quick start (crick)

```bash
cd servers/crick
cp .env.example .env
# edit .env (paths + IMAGE_NAME + IMAGE_TAG + SERVER_NAME)
./deploy.sh
```

## Rollback

```bash
cd servers/crick
IMAGE_TAG=<older_sha> ./rollback.sh
```

Or edit `.env` and set `IMAGE_TAG` to an older SHA, then run `./deploy.sh`.

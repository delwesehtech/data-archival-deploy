# data-archival-deploy

Config-only deployment repo for `data-archival`.

This repo intentionally keeps only:
- per-server `docker-compose.yml`
- `policy/` (YAML policies mounted at `/policy` in containers)
- `.env` templates
- small deploy helper scripts

Application code and image build logic stay in the `data-archival` repo.

## Layout

- `environments/crick/` - first server deployment config
- `environments/<server>/` - clone from `crick` for each additional server

## Deploy model

1. Build and push image from `data-archival` tagged as:
   - `...:<git-sha>`
   - `...:latest`
2. Update `IMAGE_TAG=<git-sha>` in target environment `.env`.
3. Run deploy script on the server from that environment folder.

## Local helpers (`aliases.sh`)

From the repo root, run **`./aliases.sh`** (executable). That starts an interactive **bash** with helpers loaded; type **`avd_help`** for the list. Type **`exit`** to leave that shell. To load into your **current** shell instead: `source ./aliases.sh`.

## Quick start (crick)

```bash
cd environments/crick
cp .env.example .env
# edit .env (paths + IMAGE_NAME + IMAGE_TAG + SERVER_NAME)
./deploy.sh
```

## Rollback

```bash
cd environments/crick
IMAGE_TAG=<older_sha> ./rollback.sh
```

Or edit `.env` and set `IMAGE_TAG` to an older SHA, then run `./deploy.sh`.

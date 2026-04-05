# crick deployment

This folder is self-contained for one server. Each host runs **three separate operations**:

1. **Cleanup scratch** — `cleanup_scratch` (policy: `policy/cleanup_policy_scratch.yaml`)
2. **Cleanup archive** — `cleanup_archive` (policy: `policy/cleanup_policy_archive_drive.yaml`)
3. **Data archival** — `archival` (policy: `policy/archive_policy.yaml`, scratch → archive drive; not a delete/cleanup job)

Compose bind-mounts `SCRATCH_PATH` and `ARCHIVE_PATH` at the same path in the container. Paths in `policy/*.yaml` must match your machine (see `.env.example` for a `/tmp/...` layout).

Files:
- `docker-compose.yml`
- `policy/archive_policy.yaml`
- `policy/cleanup_policy_scratch.yaml`
- `policy/cleanup_policy_archive_drive.yaml`
- `.env`

## 1) Configure

```bash
cp .env.example .env
```

Set:
- `IMAGE_NAME` (registry image, e.g. `ghcr.io/acme/data-archival`)
- `IMAGE_TAG` (immutable git SHA tag)
- `SCRATCH_PATH`
- `ARCHIVE_PATH`
- `SERVER_NAME`

## 2) Deploy

From `environments/crick` (after `.env` is set and the image is available locally or in a registry):

```bash
docker compose pull   # optional; when IMAGE_* points at a registry
docker compose up -d visibility
```

Run cleanup and archival jobs with `docker compose run --rm …` as below (they are not long-running services in this compose file).

## 3) Run jobs

```bash
# dry-runs
docker compose run --rm archival
docker compose run --rm cleanup_scratch
docker compose run --rm cleanup_archive

# execute
docker compose run --rm archival --execute --log-dir /app/logs
docker compose run --rm cleanup_scratch --execute --log-dir /app/logs
docker compose run --rm cleanup_archive --execute --log-dir /app/logs
```

## 4) Rollback

Set `IMAGE_TAG` in `.env` to the previous immutable image tag (or digest), then recreate containers, for example:

```bash
docker compose up -d --force-recreate visibility
```

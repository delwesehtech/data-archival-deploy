# crick deployment

This folder is self-contained for one server. Each host runs **three separate operations**:

1. **Cleanup scratch** — `cleanup_scratch` (policy: `policy/cleanup_policy_scratch.yaml`, mount: `LOCAL_SCRATCH_PATH`)
2. **Cleanup archive drive** — `cleanup_archive_drive` (policy: `policy/cleanup_policy_archive_drive.yaml`, mount: `ARCHIVE_DRIVE_PATH`)
3. **Data archival** — `archival` (policy: `policy/archive_policy.yaml`, scratch → archive drive; not a delete/cleanup job)

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
- `LOCAL_SCRATCH_PATH`
- `ARCHIVE_DRIVE_PATH`
- `SERVER_NAME`

## 2) Deploy

```bash
./deploy.sh
```

## 3) Run jobs

```bash
# dry-runs
docker compose run --rm archival
docker compose run --rm cleanup_scratch
docker compose run --rm cleanup_archive_drive

# execute
docker compose run --rm archival --execute --log-dir /app/logs
docker compose run --rm cleanup_scratch --execute --log-dir /app/logs
docker compose run --rm cleanup_archive_drive --execute --log-dir /app/logs
```

## 4) Rollback

```bash
./rollback.sh <previous_git_sha_tag>
```

The rollback is deterministic because images are pinned by immutable SHA tags.

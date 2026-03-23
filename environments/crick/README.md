# crick deployment

This folder is self-contained for one server:
- `docker-compose.yml`
- `archive_policy.yaml`
- `delete_policy.yaml`
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

```bash
./deploy.sh
```

## 3) Run jobs

```bash
# dry-runs
docker compose run --rm archival
docker compose run --rm delete

# execute
docker compose run --rm archival --execute --log-dir /app/logs
docker compose run --rm delete --execute --log-dir /app/logs
```

## 4) Rollback

```bash
./rollback.sh <previous_git_sha_tag>
```

The rollback is deterministic because images are pinned by immutable SHA tags.

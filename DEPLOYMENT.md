# Multi-server deployment runbook

## Release image (from `data-archival` repo)

```bash
cd ~/code/data-archival
export IMAGE_NAME=ghcr.io/your-org/data-archival
./scripts/build-and-push.sh amd64
```

This publishes two tags:
- `${IMAGE_NAME}:<git-sha>`
- `${IMAGE_NAME}:latest`

## Deploy to a server environment

```bash
cd ~/code/data-archival-deploy/environments/crick
cp .env.example .env
# set IMAGE_NAME and IMAGE_TAG=<git-sha>
./deploy.sh
```

## Rollback

```bash
cd ~/code/data-archival-deploy/environments/crick
./rollback.sh <older_git_sha>
```

## Add another server

1. Copy `environments/crick` to `environments/<server>`.
2. Update:
   - `.env` (`SERVER_NAME`, paths, `IMAGE_TAG`)
   - policy files (`archive_policy.yaml`, `delete_policy.yaml`)
3. Deploy with `./deploy.sh`.

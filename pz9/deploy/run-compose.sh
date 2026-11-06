#!/usr/bin/env bash
set -euo pipefail
# Intended only for a previously approved EC2 deployment directory.
# This script does not install Docker, create EC2 or remove unrelated PM2 apps.
test -f .env && test -f docker-compose.yml
chmod 600 .env
docker compose version
# The lesson's old standalone nodeapp container is removed only if it is NOT
# a Compose-managed container. Never remove the current Compose app or DB volume.
if docker inspect nodeapp >/dev/null 2>&1; then
  owner=$(docker inspect --format '{{ index .Config.Labels "com.docker.compose.project" }}' nodeapp)
  if [ -n "$owner" ]; then
    echo 'Refusing to remove Compose-managed container named nodeapp' >&2; exit 1
  fi
  docker rm -f nodeapp
else
  docker rm -f nodeapp >/dev/null 2>&1 || true
fi
docker compose -p devops-nodeapp pull
docker compose -p devops-nodeapp up -d --no-build --wait --wait-timeout 120
curl --fail --silent --show-error http://127.0.0.1:3000/healthz
printf '\n'
docker compose -p devops-nodeapp ps
# No down -v: PostgreSQL data must survive application recreation.

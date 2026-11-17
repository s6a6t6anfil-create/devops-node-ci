#!/usr/bin/env bash
set -euo pipefail
[[ $(id -un) == ubuntu && "$PWD" == "$HOME/optima-pz12" ]]
test -f .env && test -f docker-compose.yml
chmod 600 .env
sudo -n docker compose version
compose() { sudo -n docker compose -p optima-pz12 --env-file .env -f docker-compose.yml "$@"; }
compose pull
compose up -d --no-build --wait --wait-timeout 120
curl -fsS --max-time 5 http://127.0.0.1:3000/healthz
printf '\n'
curl -fsS --max-time 5 -X POST http://127.0.0.1:3000/visits
printf '\n'
curl -fsS --max-time 5 http://127.0.0.1:3000/visits
printf '\n'
compose ps

#!/usr/bin/env bash
set -euo pipefail
# MANUAL ONLY after EC2, OS version, costs, SSH and PM2 cleanup are approved.
# Follow Docker's official Ubuntu installation instructions; do not pipe a
# remote convenience script into a privileged shell.
if ! command -v docker >/dev/null || ! docker compose version >/dev/null; then
  echo 'Install Docker Engine and Compose plugin using https://docs.docker.com/engine/install/ubuntu/' >&2
  exit 1
fi
if command -v pm2 >/dev/null; then
  if [ "${ALLOW_PM2_REMOVAL:-0}" != 1 ]; then
    echo 'Review pm2 jlist; explicit ALLOW_PM2_REMOVAL=1 required for lesson cleanup.' >&2; exit 1
  fi
  # Refuse to touch other projects managed by this user's PM2.
  pm2 jlist | node -e 'let s="";process.stdin.on("data",x=>s+=x);process.stdin.on("end",()=>{if(JSON.parse(s).some(x=>x.name!=="nodeapp")){console.error("Other PM2 applications exist; stop and review");process.exit(1)}})'
  pm2 delete nodeapp || true
  pm2 save --force
  pm2 kill
  npm uninstall -g pm2
  if command -v pm2 >/dev/null; then echo 'A system PM2 installation still exists; review its owner before removing' >&2; exit 1; fi
fi
printf 'Docker available; reviewed PM2 cleanup finished.\n'

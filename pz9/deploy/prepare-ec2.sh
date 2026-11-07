#!/usr/bin/env bash
set -euo pipefail
[[ "$(id -un)" == ubuntu ]]
. /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 20.04 ]]
# Keep the approved lab within its two-hour operating window.
sudo shutdown -h +110 "Optima PZ9 lab time limit"
if ! command -v docker >/dev/null || ! sudo docker compose version >/dev/null; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL --retry 2 https://download.docker.com/linux/ubuntu/gpg -o /tmp/optima-docker.asc
  sudo install -m 0644 /tmp/optima-docker.asc /etc/apt/keyrings/docker.asc
  printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu focal stable' | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
sudo systemctl enable --now docker
export PATH="$HOME/.local/opt/node-v24.22.2/bin:$HOME/.local/bin:$PATH"
export PM2_HOME="$HOME/.pm2-optima-pz6"
if command -v pm2 >/dev/null; then
  pm2 jlist | node -e 'let s="";process.stdin.on("data",x=>s+=x);process.stdin.on("end",()=>{if(JSON.parse(s).some(x=>x.name!=="optima-nodeapp"))process.exit(1)})'
  if pm2 describe optima-nodeapp >/dev/null 2>&1; then pm2 delete optima-nodeapp; fi
  pm2 save --force
  pm2 kill
  npm uninstall --global --prefix "$HOME/.local" pm2
fi
sudo docker version --format '{{.Server.Version}}'
sudo docker compose version

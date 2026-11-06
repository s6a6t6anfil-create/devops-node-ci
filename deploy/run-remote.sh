#!/usr/bin/env bash
set -euo pipefail
# Execute only on the separately approved, dedicated EC2 training instance.
source_dir="${1:?Usage: run-remote.sh INCOMING_DIRECTORY APP_ENTRY}"
app_entry="${2:?Usage: run-remote.sh INCOMING_DIRECTORY APP_ENTRY}"
case "$source_dir" in "$HOME"/nodeapp/incoming/*) ;; *) echo 'Unexpected source directory.' >&2; exit 2 ;; esac
[[ "${source_dir##*/}" =~ ^[a-f0-9]{40}$ ]] || { echo 'Invalid commit directory.' >&2; exit 2; }
[[ -d "$source_dir" && ! -L "$source_dir" ]] || { echo 'Missing source directory.' >&2; exit 2; }
[[ "$app_entry" == deploy/server.cjs ]] || { echo 'Unexpected application entry.' >&2; exit 2; }
# Install the same Node.js major version used by CI under the training user.
node_version=24.22.2
node_home="$HOME/.local/opt/node-v$node_version"
if [[ ! -x "$node_home/bin/node" ]]; then
  archive="node-v$node_version-linux-x64.tar.xz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsS --retry 2 --max-time 120 \
    "https://nodejs.org/dist/v$node_version/$archive" -o "$tmp/$archive"
  printf '%s  %s\n' 48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75 "$tmp/$archive" | sha256sum -c -
  tar -xJf "$tmp/$archive" -C "$tmp"
  mkdir -p "$HOME/.local/opt"
  mv "$tmp/node-v$node_version-linux-x64" "$node_home"
fi
export PATH="$node_home/bin:$HOME/.local/bin:$PATH"
if ! command -v pm2 >/dev/null; then
  npm install --global --prefix "$HOME/.local" pm2@7.1.2
fi
node --version
pm2 --version
# Each deploy builds in a clean directory: the original mkdir dist is preserved.
mkdir -p "$HOME/nodeapp/releases"
release_dir="$(mktemp -d "$HOME/nodeapp/releases/release.XXXXXX")"
cp -R "$source_dir/." "$release_dir/"
cd "$release_dir"
npm install
node index.js | grep -Fx 'Hello world!'
npm run build
[[ "$(cat dist/index.html)" == '<h1>Hello CI</h1>' ]]
export PM2_HOME="$HOME/.pm2-optima-pz6"
if pm2 describe optima-nodeapp >/dev/null 2>&1; then pm2 delete optima-nodeapp; fi
pm2 start "$release_dir/$app_entry" --name optima-nodeapp --cwd "$release_dir"
for i in $(seq 1 10); do
  if [[ "$(curl --silent --fail http://127.0.0.1:3000/healthz || true)" == ok ]]; then break; fi
  sleep 1
done
[[ "$(curl --silent --fail http://127.0.0.1:3000/)" == '<h1>Hello CI</h1>' ]]
pm2 save
pm2 describe optima-nodeapp

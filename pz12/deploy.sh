#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${RUNNER_TEMP:?Only run in the reviewed Actions job}"
[[ "$EC2_USER" == ubuntu && "$EC2_HOST" == "$EXPECTED_IP" ]]
[[ "$HUB_USER" =~ ^[a-z0-9][a-z0-9_-]*$ && "$IMAGE_TAG" =~ ^pz12-[0-9a-f]{12}$ ]]
[[ "$INSTANCE_ID" =~ ^i-[0-9a-f]{17}$ && "$POSTGRES_PASSWORD" =~ ^[A-Za-z0-9._-]{20,}$ ]]
[[ -n "$EC2_SSH_KEY_B64" && -n "$EC2_KNOWN_HOSTS" ]]
python3 -c 'import ipaddress,os; assert ipaddress.IPv4Address(os.environ["EC2_HOST"]).is_global'
work=$(mktemp -d "$RUNNER_TEMP/pz12-ssh.XXXXXX")
trap 'rm -rf "$work"' EXIT
printf '%s' "$EC2_SSH_KEY_B64" | base64 --decode > "$work/key"
printf '%s\n' "$EC2_KNOWN_HOSTS" > "$work/known_hosts"
ssh-keygen -y -P '' -f "$work/key" >/dev/null
ssh-keygen -F "$EC2_HOST" -f "$work/known_hosts" >/dev/null
runner_ipv4=$(curl -4fsS --max-time 10 https://checkip.amazonaws.com)
python3 -c 'import ipaddress,sys; assert ipaddress.IPv4Address(sys.argv[1]).is_global' "$runner_ipv4"
printf 'Temporary TCP22 rule required, only for this runner: %s/32\n' "$runner_ipv4"
for attempt in {1..72}; do
  nc -z -w 2 "$EC2_HOST" 22 && break
  if [[ "$attempt" == 72 ]]; then echo 'Approved SSH access was not added; exit.' >&2; exit 1; fi
  sleep 5
done
opts=(-i "$work/key" -o IdentitiesOnly=yes -o UserKnownHostsFile="$work/known_hosts" -o StrictHostKeyChecking=yes -o BatchMode=yes -o ConnectTimeout=15)
target="$EC2_USER@$EC2_HOST"
# Verify EC2 identity before sending the database password or deploy files.
actual=$(ssh "${opts[@]}" "$target" 'token=$(curl -fsS --max-time 5 -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" http://169.254.169.254/latest/api/token) && curl -fsS --max-time 5 -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id')
[[ "$actual" == "$INSTANCE_ID" ]]
ssh "${opts[@]}" "$target" 'umask 077; install -d -m 700 "$HOME/optima-pz12"'
printf 'DOCKERHUB_USERNAME=%s\nIMAGE_TAG=%s\nPOSTGRES_PASSWORD=%s\nAPP_BIND_IP=0.0.0.0\nAPP_PORT=3000\n' "$HUB_USER" "$IMAGE_TAG" "$POSTGRES_PASSWORD" > "$work/.env"
scp "${opts[@]}" "$work/.env" pz9/docker-compose.yml pz12/run-compose.sh "$target:optima-pz12/"
ssh "${opts[@]}" "$target" 'cd "$HOME/optima-pz12" && bash run-compose.sh'
# Token is not needed to pull the public PZ9 image from EC2.

#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/scripts/settings.sh"

API_PORT=$(printf '%s' "$SETTINGS" | jq -r '.api_port')
export KUBECONFIG="$ROOT/terraform/kubeconfig"
KEY=${SSH_PRIVATE_KEY:-$HOME/.ssh/id_ed25519}
PORT=${TUNNEL_PORT:-16443}
REGION=$(terraform -chdir="$ROOT/terraform" output -raw aws_region)
NAME=$(terraform -chdir="$ROOT/terraform" output -raw cluster_name)
PUBLIC_IP=$(terraform -chdir="$ROOT/terraform" output -raw control_plane_public_ip)
PRIVATE_IP=$(terraform -chdir="$ROOT/terraform" console <<< 'local.control_plane_private_ip' | tr -d '"')

if [ ! -f "$KEY" ]; then
  echo "Private key not found: $KEY" >&2
  exit 1
fi

# Replace the kubeconfig only after downloading and configuring it successfully.
umask 077
TMP=$(mktemp "$ROOT/terraform/.kubeconfig.XXXXXX")
trap 'rm -f "$TMP"' EXIT
aws ssm get-parameter --region "$REGION" --name "/$NAME/kubeconfig" \
  --with-decryption --query Parameter.Value --output text > "$TMP"

CLUSTER=$(kubectl --kubeconfig="$TMP" config view --minify -o jsonpath='{.contexts[0].context.cluster}')
test -n "$CLUSTER"
kubectl --kubeconfig="$TMP" config set-cluster "$CLUSTER" \
  --server="https://127.0.0.1:$PORT" --tls-server-name="$PRIVATE_IP"
mv "$TMP" "$KUBECONFIG"

echo 'Keeping the tunnel open. Use another terminal for make addons/deploy/preview.'
exec ssh -i "$KEY" -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
  -N -L "127.0.0.1:$PORT:$PRIVATE_IP:$API_PORT" "ubuntu@$PUBLIC_IP"

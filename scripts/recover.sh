#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/scripts/settings.sh"
JOIN_TTL=$(printf '%s' "$SETTINGS" | jq -r '.join_token_ttl')
KEY=${SSH_PRIVATE_KEY:-$HOME/.ssh/id_ed25519}
REGION=$(terraform -chdir="$ROOT/terraform" output -raw aws_region)
NAME=$(terraform -chdir="$ROOT/terraform" output -raw cluster_name)
CP=$(terraform -chdir="$ROOT/terraform" output -raw control_plane_public_ip)
test -f "$KEY"

# Repair the control plane first, then publish a fresh join command for workers.
ssh -i "$KEY" "ubuntu@$CP" "sudo bash -s -- '$REGION' '$NAME' '$JOIN_TTL'" <<'REMOTE'
set -euo pipefail
region=$1
cluster_name=$2
join_ttl=$3

cloud-init status --wait || true
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y conntrack

if [ ! -s /etc/kubernetes/admin.conf ]; then
  if [ -e /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
    echo 'Partial initialization detected; refusing to rerun kubeadm.' >&2
    exit 1
  fi

  SCRIPT=/root/cluster-bootstrap.sh
  if [ ! -f "$SCRIPT" ]; then
    SCRIPT=/var/lib/cloud/instance/scripts/part-001
  fi
  sed 's/gpg --dearmor/gpg --batch --yes --dearmor/' "$SCRIPT" | bash
fi

kubeadm token create --ttl "$join_ttl" --print-join-command > /root/join-command
aws ssm put-parameter --region "$region" --name "/$cluster_name/join-command" \
  --type SecureString --value "$(cat /root/join-command)" --overwrite
aws ssm put-parameter --region "$region" --name "/$cluster_name/kubeconfig" \
  --type SecureString --tier Advanced \
  --value "$(cat /etc/kubernetes/admin.conf)" --overwrite
REMOTE

WORKERS=$(terraform -chdir="$ROOT/terraform" output -json worker_public_ips)
while IFS= read -r IP; do
  ssh -i "$KEY" "ubuntu@$IP" "sudo bash -s -- '$REGION' '$NAME'" <<'REMOTE'
set -euo pipefail
region=$1
cluster_name=$2

cloud-init status --wait || true
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y conntrack

if [ ! -s /etc/kubernetes/kubelet.conf ]; then
  if ! command -v kubeadm >/dev/null || ! command -v aws >/dev/null; then
    SCRIPT=/root/cluster-bootstrap.sh
    if [ ! -f "$SCRIPT" ]; then
      SCRIPT=/var/lib/cloud/instance/scripts/part-001
    fi
    sed 's/gpg --dearmor/gpg --batch --yes --dearmor/' "$SCRIPT" | bash
  else
    JOIN=$(aws ssm get-parameter --region "$region" \
      --name "/$cluster_name/join-command" --with-decryption \
      --query Parameter.Value --output text)
    test -n "$JOIN" && test "$JOIN" != None
    bash -c "$JOIN"
  fi
fi

systemctl is-active kubelet
REMOTE
done < <(printf '%s' "$WORKERS" | jq -r '.[]')

echo 'Recovery complete. Run make connect, then make addons.'

#!/usr/bin/env bash
set -euo pipefail

REGION=$1
NAME=$2

INSTANCES=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:kubernetes.io/cluster/$NAME,Values=owned,shared" \
    'Name=instance-state-name,Values=running' --output json)

while IFS= read -r NODE; do
  CURRENT=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}')
  if [ -n "$CURRENT" ]; then
    continue
  fi

  # kubeadm uses the short hostname; EC2 can return the full private DNS name.
  MATCHES=$(printf '%s' "$INSTANCES" | jq --arg node "$NODE" \
    '[.Reservations[].Instances[] | select(
      (.PrivateDnsName == $node) or
      ((.PrivateDnsName | split(".")[0]) == $node)
    )]')

  if [ "$(printf '%s' "$MATCHES" | jq length)" -ne 1 ]; then
    echo "Cannot uniquely match $NODE to a tagged instance; refusing to patch." >&2
    exit 1
  fi

  ID=$(printf '%s' "$MATCHES" | jq -r '.[0].InstanceId')
  AZ=$(printf '%s' "$MATCHES" | jq -r '.[0].Placement.AvailabilityZone')
  kubectl patch node "$NODE" --type=merge -p "{\"spec\":{\"providerID\":\"aws:///$AZ/$ID\"}}"
done < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

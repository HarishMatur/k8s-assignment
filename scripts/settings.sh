#!/usr/bin/env bash
# Source this file to load the same non-secret settings used by Terraform.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if ! command -v jq >/dev/null; then
  echo 'jq is required.' >&2
  exit 1
fi

SETTINGS=$(terraform -chdir="$ROOT/terraform" console <<'HCL'
jsonencode({addon_versions = var.addon_versions, pod_cidr = var.pod_cidr, api_port = var.bootstrap.api_port, join_token_ttl = var.bootstrap.join_token_ttl})
HCL
)
# Terraform console returns a quoted JSON string; unwrap it for callers.
SETTINGS=$(printf '%s' "$SETTINGS" | jq -r '.')

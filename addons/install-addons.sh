#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?Set KUBECONFIG to the exported admin kubeconfig}"
if ! kubectl --request-timeout=5s get --raw=/readyz >/dev/null; then
  echo 'Kubernetes API is unreachable. Run make connect successfully and keep it running before make addons.' >&2
  exit 1
fi
source "$(dirname "$0")/../scripts/settings.sh"
CALICO_VERSION=${CALICO_VERSION:-$(printf '%s' "$SETTINGS" | jq -r '.addon_versions.calico')}
CCM_VERSION=${CCM_VERSION:-$(printf '%s' "$SETTINGS" | jq -r '.addon_versions.ccm_chart')}
CCM_IMAGE_TAG=${CCM_IMAGE_TAG:-$(printf '%s' "$SETTINGS" | jq -r '.addon_versions.ccm_image')}
EBS_CSI_VERSION=${EBS_CSI_VERSION:-$(printf '%s' "$SETTINGS" | jq -r '.addon_versions.ebs_csi')}
POD_CIDR=${POD_CIDR:-$(printf '%s' "$SETTINGS" | jq -r '.pod_cidr')}
command -v jq >/dev/null

# Only remove this incompatible leftover if it contains no user resources.
if [ "$CALICO_VERSION" = v3.29.3 ] && [ -n "$(kubectl get crd managementclusterconnections.operator.tigera.io --ignore-not-found -o name)" ]; then
  COUNT=$(kubectl get managementclusterconnections.operator.tigera.io -o json | jq '.items | length')
  [ "$COUNT" -eq 0 ] || { echo 'Management-cluster objects exist; refusing CRD cleanup.' >&2; exit 1; }
  kubectl delete crd managementclusterconnections.operator.tigera.io
  if [ -n "$(kubectl -n tigera-operator get deployment tigera-operator --ignore-not-found -o name)" ]; then
    kubectl -n tigera-operator rollout restart deployment/tigera-operator
  fi
fi

helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

# Install the CRDs from the same release as the operator.
kubectl apply --server-side -f \
  "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/operator-crds.yaml"
kubectl wait --for=condition=Established --timeout=120s \
  crd/installations.operator.tigera.io \
  crd/apiservers.operator.tigera.io \
  crd/ippools.crd.projectcalico.org

helm upgrade --install calico projectcalico/tigera-operator \
  --namespace tigera-operator --create-namespace --version "$CALICO_VERSION" --skip-crds
sed "s|192.168.0.0/16|$POD_CIDR|" "$(dirname "$0")/cni/calico-installation.yaml" | kubectl apply -f -

REGION=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw aws_region)
CLUSTER_NAME=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw cluster_name 2>/dev/null || true)
if [ -z "$CLUSTER_NAME" ]; then CLUSTER_NAME=${TF_VAR_cluster_name:-harish-k8s-assignment}; fi
bash "$(dirname "$0")/../scripts/node-identities.sh" "$REGION" "$CLUSTER_NAME"

# Helm 4 SSA conflicts with the host-network bootstrap patch on repeat runs.
# Helm 3 already uses client-side updates; scope this compatibility flag to CCM.
CCM_APPLY_FLAGS=()
HELM_UPGRADE_HELP=$(helm upgrade --help)
if [[ "$HELM_UPGRADE_HELP" == *--server-side* ]]; then
  CCM_APPLY_FLAGS+=(--server-side=false)
fi
helm upgrade --install aws-cloud-controller-manager aws-cloud-controller-manager/aws-cloud-controller-manager \
  "${CCM_APPLY_FLAGS[@]}" \
  --namespace kube-system --version "$CCM_VERSION" \
  --values "$(dirname "$0")/metallb/values.yaml" \
  --set image.tag="$CCM_IMAGE_TAG" \
  --set args[0]="--cloud-provider=aws" \
  --set args[1]="--cluster-name=$CLUSTER_NAME" \
  --set args[2]="--configure-cloud-routes=false" \
  --set-string nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set tolerations[1].key="node.cloudprovider.kubernetes.io/uninitialized" \
  --set tolerations[1].operator=Exists \
  --set tolerations[1].effect=NoSchedule \
  --set tolerations[2].key="node.kubernetes.io/not-ready" \
  --set tolerations[2].operator=Exists \
  --set tolerations[2].effect=NoSchedule

# This chart does not expose hostNetwork; CCM must start before the CNI.
kubectl -n kube-system patch daemonset aws-cloud-controller-manager --type=merge \
  -p '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"Default","tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"},{"key":"node.cloudprovider.kubernetes.io/uninitialized","operator":"Exists","effect":"NoSchedule"},{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoSchedule"}]}}}}'
kubectl -n kube-system rollout status daemonset/aws-cloud-controller-manager --timeout=5m

# kube-proxy can cache loopback when it starts before CCM supplies node IPs.
for attempt in $(seq 1 60); do
  UNINITIALIZED=$(kubectl get nodes -o go-template='{{range .items}}{{range .spec.taints}}{{if eq .key "node.cloudprovider.kubernetes.io/uninitialized"}}pending{{end}}{{end}}{{end}}')
  if [ -z "$UNINITIALIZED" ]; then break; fi
  if [ "$attempt" -eq 60 ]; then
    echo "AWS node initialization timed out; inspect CCM logs." >&2
    exit 1
  fi
  sleep 10
done
kubectl -n kube-system rollout restart daemonset/kube-proxy
kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=3m
for attempt in $(seq 1 60); do
  if [ -n "$(kubectl -n calico-system get daemonset calico-node --ignore-not-found -o name)" ]; then break; fi
  [ "$attempt" -lt 60 ] || { echo 'Calico DaemonSet was not created; inspect operator logs.' >&2; exit 1; }
  sleep 5
done
kubectl -n calico-system rollout status daemonset/calico-node --timeout=10m

helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system --version "$EBS_CSI_VERSION" \
  --set controller.region="$REGION"
kubectl -n kube-system rollout restart daemonset/ebs-csi-node
kubectl -n kube-system rollout status daemonset/ebs-csi-node --timeout=5m
kubectl -n kube-system rollout status deployment/ebs-csi-controller --timeout=5m
kubectl apply -f "$(dirname "$0")/csi/storageclass.yaml"

kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide
kubectl get pods -A

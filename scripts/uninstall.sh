#!/usr/bin/env bash
set -euo pipefail

MGMT_KUBECONFIG=${MGMT_KUBECONFIG:-"$HOME/.kube/rancher-mgmt.yaml"}
DOWNSTREAM_KUBECONFIG=${DOWNSTREAM_KUBECONFIG:-"$HOME/.kube/config"}
FLEET_NAMESPACE=${FLEET_NAMESPACE:-"fleet-default"}
GITREPO_NAME=${GITREPO_NAME:-"kubeflow"}

PURGE_NAMESPACES=false
PURGE_SHARED=false
DELETE_PVCS=false
DRY_RUN=false
WAIT=false

usage() {
  cat <<'USAGE'
Uninstall Kubeflow Fleet bundles.

Usage:
  scripts/uninstall.sh [options]

Options:
  --gitrepo NAME              GitRepo name to delete (default: kubeflow)
  --fleet-namespace NS        Fleet namespace (default: fleet-default)
  --mgmt-kubeconfig PATH      Rancher management kubeconfig (default: ~/.kube/rancher-mgmt.yaml)
  --downstream-kubeconfig PATH Downstream cluster kubeconfig (default: ~/.kube/config)
  --purge-namespaces          Delete core Kubeflow namespaces
  --purge-shared              Also delete shared namespaces (istio-system, cert-manager, monitoring)
  --delete-pvcs               Delete PVCs in targeted namespaces
  --wait                      Wait for GitRepo deletion
  --dry-run                   Print actions without executing
  -h, --help                  Show this help

Environment variables:
  MGMT_KUBECONFIG, DOWNSTREAM_KUBECONFIG, FLEET_NAMESPACE, GITREPO_NAME
USAGE
}

run() {
  if $DRY_RUN; then
    echo "+ $*"
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gitrepo) GITREPO_NAME="$2"; shift 2;;
    --fleet-namespace) FLEET_NAMESPACE="$2"; shift 2;;
    --mgmt-kubeconfig) MGMT_KUBECONFIG="$2"; shift 2;;
    --downstream-kubeconfig) DOWNSTREAM_KUBECONFIG="$2"; shift 2;;
    --purge-namespaces) PURGE_NAMESPACES=true; shift;;
    --purge-shared) PURGE_SHARED=true; shift;;
    --delete-pvcs) DELETE_PVCS=true; shift;;
    --wait) WAIT=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
 done

if kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$FLEET_NAMESPACE" get gitrepo "$GITREPO_NAME" >/dev/null 2>&1; then
  echo "Deleting GitRepo $FLEET_NAMESPACE/$GITREPO_NAME (management cluster)"
  run kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$FLEET_NAMESPACE" delete gitrepo "$GITREPO_NAME"
else
  echo "GitRepo $FLEET_NAMESPACE/$GITREPO_NAME not found (skipping)"
fi

if $WAIT; then
  echo "Waiting for GitRepo deletion..."
  if ! $DRY_RUN; then
    for _ in $(seq 1 60); do
      if ! kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$FLEET_NAMESPACE" get gitrepo "$GITREPO_NAME" >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done
  fi
fi

if $PURGE_NAMESPACES; then
  namespaces=(kubeflow kubeflow-system auth oauth2-proxy knative-serving)
  if $PURGE_SHARED; then
    namespaces+=(istio-system cert-manager monitoring)
  fi

  if $DELETE_PVCS; then
    for ns in "${namespaces[@]}"; do
      echo "Deleting PVCs in namespace $ns"
      run kubectl --kubeconfig "$DOWNSTREAM_KUBECONFIG" -n "$ns" delete pvc --all --ignore-not-found
    done
  fi

  for ns in "${namespaces[@]}"; do
    if kubectl --kubeconfig "$DOWNSTREAM_KUBECONFIG" get ns "$ns" >/dev/null 2>&1; then
      echo "Deleting namespace $ns"
      run kubectl --kubeconfig "$DOWNSTREAM_KUBECONFIG" delete ns "$ns"
    fi
  done
fi

echo "Done."

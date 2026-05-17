#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="idp-concept-acceptance"
KIND_IMAGE="kindest/node:v1.33.0"
KEEP_CLUSTER="false"
SKIP_CREATE="false"
PREFLIGHT_ONLY="false"
CASES=("basic")
CASES_SELECTED="false"
ALL_CASES=("basic" "webapp" "database" "dataprepper" "opensearch-dashboards" "elasticsearch" "kibana" "logstash")
SEARCH_CASES=("opensearch-dashboards" "elasticsearch" "kibana" "logstash")

usage() {
  cat <<'EOF'
Usage: ./scripts/acceptance_kind.sh [options]

Options:
  --case <name>        Run one case/group. Supported: basic, webapp, database,
                       dataprepper, opensearch-dashboards, elasticsearch,
                       kibana, logstash, search, all. Can be repeated.
  --cluster-name <n>   Kind cluster name (default: idp-concept-acceptance)
  --kind-image <img>   Kind node image (default: kindest/node:v1.33.0)
  --keep-cluster       Do not delete the kind cluster on exit
  --skip-create        Reuse an existing cluster/context
  --preflight-only     Check local tools and exit without creating a cluster
  -h, --help           Show this help

Default runs only the lightweight `basic` workload. Heavier cases are opt-in.
EOF
}

set_cases() {
  local selected="$1"
  if [[ "$CASES_SELECTED" == "false" ]]; then
    CASES=()
    CASES_SELECTED="true"
  fi
  case "$selected" in
    basic|webapp|database|dataprepper|opensearch-dashboards|elasticsearch|kibana|logstash) CASES+=("$selected") ;;
    search) CASES+=("${SEARCH_CASES[@]}") ;;
    all) CASES+=("${ALL_CASES[@]}") ;;
    *) echo "Unsupported case: $selected" >&2; exit 2 ;;
  esac
}

case_file_for() {
  local case_name="$1"
  case "$case_name" in
    basic) echo "tests/acceptance/cases/basic_workload.k" ;;
    webapp) echo "tests/acceptance/cases/webapp_workload.k" ;;
    database) echo "tests/acceptance/cases/database_workload.k" ;;
    dataprepper) echo "tests/acceptance/cases/dataprepper_workload.k" ;;
    opensearch-dashboards) echo "tests/acceptance/cases/opensearch_dashboards_workload.k" ;;
    elasticsearch) echo "tests/acceptance/cases/elasticsearch_workload.k" ;;
    kibana) echo "tests/acceptance/cases/kibana_workload.k" ;;
    logstash) echo "tests/acceptance/cases/logstash_workload.k" ;;
    *) echo "Unsupported case: $case_name" >&2; exit 2 ;;
  esac
}

namespace_for() {
  local case_name="$1"
  case "$case_name" in
    basic) echo "idp-acceptance-basic" ;;
    webapp) echo "idp-acceptance-webapp" ;;
    database) echo "idp-acceptance-database" ;;
    dataprepper) echo "idp-acceptance-dataprepper" ;;
    opensearch-dashboards) echo "idp-acceptance-opensearch-dashboards" ;;
    elasticsearch) echo "idp-acceptance-elasticsearch" ;;
    kibana) echo "idp-acceptance-kibana" ;;
    logstash) echo "idp-acceptance-logstash" ;;
    *) echo "Unsupported case: $case_name" >&2; exit 2 ;;
  esac
}

is_apply_case() {
  local case_name="$1"
  case "$case_name" in
    basic|webapp|database|dataprepper) return 0 ;;
    opensearch-dashboards|elasticsearch|kibana|logstash) return 1 ;;
    *) echo "Unsupported case: $case_name" >&2; exit 2 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) shift; set_cases "${1:?missing case name}" ;;
    --cluster-name) shift; CLUSTER_NAME="${1:?missing cluster name}" ;;
    --kind-image) shift; KIND_IMAGE="${1:?missing kind image}" ;;
    --keep-cluster) KEEP_CLUSTER="true" ;;
    --skip-create) SKIP_CREATE="true" ;;
    --preflight-only) PREFLIGHT_ONLY="true" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    return 1
  fi
}

preflight() {
  local missing=0
  for cmd in docker kind kubectl kcl; do
    require_cmd "$cmd" || missing=1
  done
  if [[ "$missing" -ne 0 ]]; then
    echo "Install missing tools before running kind acceptance tests." >&2
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is installed but not reachable by the current user/session." >&2
    return 1
  fi
}

cleanup() {
  if [[ "$KEEP_CLUSTER" == "false" && "$SKIP_CREATE" == "false" ]]; then
    kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
  fi
}

render_case() {
  local case_name="$1"
  local output_file="$2"
  local case_file
  case_file="$(case_file_for "$case_name")"
  (cd "$ROOT_DIR/framework" && kcl run "$case_file") > "$output_file"
}

ensure_case_namespace() {
  local case_name="$1"
  local namespace
  namespace="$(namespace_for "$case_name")"
  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
}

apply_case() {
  local case_name="$1"
  local manifest_file="$2"
  kubectl apply -f "$manifest_file"
  case "$case_name" in
    basic)
      kubectl -n idp-acceptance-basic rollout status deploy/acceptance-pause --timeout=180s
      kubectl -n idp-acceptance-basic get deploy,svc,cm
      ;;
    webapp)
      kubectl -n idp-acceptance-webapp rollout status deploy/acceptance-webapp --timeout=180s
      kubectl -n idp-acceptance-webapp get deploy,svc,cm
      ;;
    database)
      kubectl -n idp-acceptance-database rollout status deploy/acceptance-db --timeout=180s
      kubectl -n idp-acceptance-database get deploy,svc,pvc
      kubectl get pv acceptance-db-pv
      ;;
    dataprepper)
      kubectl -n idp-acceptance-dataprepper rollout status deploy/data-prepper --timeout=300s
      kubectl -n idp-acceptance-dataprepper get deploy,svc,cm
      ;;
  esac
}

preflight
if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  echo "Preflight OK: docker, kind, kubectl, and kcl are available."
  exit 0
fi

trap cleanup EXIT

if [[ "$SKIP_CREATE" == "false" ]]; then
  kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
  kind create cluster --name "$CLUSTER_NAME" --image "$KIND_IMAGE" --wait 120s
else
  kubectl cluster-info >/dev/null
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"; cleanup' EXIT

for case_name in "${CASES[@]}"; do
  echo "==> Rendering acceptance case: $case_name"
  manifest_file="$TMP_DIR/${case_name}.yaml"
  render_case "$case_name" "$manifest_file"

  echo "==> Server-side dry-run: $case_name"
  ensure_case_namespace "$case_name"
  kubectl apply --dry-run=server -f "$manifest_file"

  if is_apply_case "$case_name"; then
    echo "==> Applying and waiting: $case_name"
    apply_case "$case_name" "$manifest_file"
  else
    echo "==> Skipping apply for dry-run-only case: $case_name"
  fi
done

echo "==> Acceptance checks complete"



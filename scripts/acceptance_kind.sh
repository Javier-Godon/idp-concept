#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="idp-concept-acceptance"
KIND_IMAGE="kindest/node:v1.33.0"
KEEP_CLUSTER="false"
KEEP_CASE_RESOURCES="false"
SKIP_CREATE="false"
PREFLIGHT_ONLY="false"
CASES=("basic")
CASES_SELECTED="false"
APPLY_CASES=("basic" "webapp" "database" "webapp-service-account-rollout" "webapp-database-stack-rollout" "elasticsearch-kibana-stack-rollout" "elk-stack-rollout" "webapp-dataprepper-stack-rollout" "webapp-opensearch-dashboards-stack-rollout" "webapp-elk-stack-rollout" "dataprepper-elk-stack-rollout" "webapp-dataprepper-elk-stack-rollout" "webapp-database-dataprepper-stack-rollout")
SEARCH_CASES=("opensearch" "opensearch-dashboards" "elasticsearch" "kibana" "logstash" "elasticsearch-v9" "kibana-v9" "logstash-v9")
DATA_CASES=("database" "postgresql" "mongodb" "rabbitmq" "redis" "redis-cluster" "kafka" "minio-tenant" "minio-helm" "questdb" "valkey")
PLATFORM_CASES=("backstage" "observability" "opentelemetry" "vault" "keycloak" "ceph" "longhorn" "openbao")
INTEGRATION_CASES=("dataprepper-opensearch" "keycloak-postgresql" "persistence-longhorn" "persistence-ceph" "webapp-postgresql-stack" "webapp-kafka-stack" "webapp-rabbitmq-stack" "webapp-redis-stack" "webapp-mongodb-stack")
ROLLOUT_CASES=("dataprepper-rollout" "opensearch-dashboards-rollout" "elasticsearch-rollout" "kibana-rollout" "logstash-rollout" "webapp-probes-rollout" "webapp-service-account-rollout" "webapp-database-stack-rollout" "elasticsearch-kibana-stack-rollout" "elk-stack-rollout" "webapp-dataprepper-stack-rollout" "webapp-opensearch-dashboards-stack-rollout" "webapp-elk-stack-rollout" "dataprepper-elk-stack-rollout" "webapp-dataprepper-elk-stack-rollout" "webapp-database-dataprepper-stack-rollout")
TEMPLATE_CASES=("webapp" "database" "dataprepper" "opensearch" "opensearch-dashboards" "elasticsearch" "kibana" "logstash" "elasticsearch-v9" "kibana-v9" "logstash-v9" "kafka" "postgresql" "mongodb" "rabbitmq" "redis" "redis-cluster" "keycloak" "backstage" "questdb" "minio-tenant" "minio-helm" "observability" "opentelemetry" "vault" "ceph" "longhorn" "valkey" "openbao")
ALL_CASES=("basic" "${TEMPLATE_CASES[@]}" "${INTEGRATION_CASES[@]}" "${ROLLOUT_CASES[@]}")

usage() {
  cat <<'EOF_USAGE'
Usage: ./scripts/acceptance_kind.sh [options]

Options:
  --case <name>        Run one case/group. Supported groups: basic, search,
                       data, platform, templates, integrations, rollouts, all.
                       Individual cases can be any fixture name such as webapp,
                       kafka, postgresql, minio-helm, opentelemetry,
                       elasticsearch-v9, dataprepper-opensearch,
                        dataprepper-rollout, webapp-probes-rollout,
                        webapp-service-account-rollout,
                        webapp-database-stack-rollout,
                        elasticsearch-kibana-stack-rollout,
                        elk-stack-rollout,
                        webapp-dataprepper-stack-rollout,
                        webapp-opensearch-dashboards-stack-rollout,
                        webapp-elk-stack-rollout,
                        dataprepper-elk-stack-rollout,
                        webapp-dataprepper-elk-stack-rollout,
                        webapp-database-dataprepper-stack-rollout,
                        webapp-postgresql-stack,
                        webapp-kafka-stack,
                        webapp-rabbitmq-stack,
                        webapp-redis-stack,
                        webapp-mongodb-stack,
                        or persistence-longhorn.
                       Can be repeated.
  --cluster-name <n>   Kind cluster name (default: idp-concept-acceptance)
  --kind-image <img>   Kind node image (default: kindest/node:v1.33.0)
  --keep-cluster       Do not delete the kind cluster on exit
  --keep-case-resources
                       Do not delete each case's resources after it passes
  --skip-create        Reuse an existing cluster/context
  --preflight-only     Check local tools and exit without creating a cluster
  -h, --help           Show this help

Default runs only the lightweight `basic` workload. Heavier template cases are opt-in.
When a group is selected, cases are executed one by one and successful case
resources are deleted before the next case unless --keep-case-resources is set.
EOF_USAGE
}

contains_case() {
  local needle="$1"; shift
  local case_name
  for case_name in "$@"; do
    [[ "$case_name" == "$needle" ]] && return 0
  done
  return 1
}

add_case() {
  local selected="$1"
  if ! contains_case "$selected" "${ALL_CASES[@]}"; then
    echo "Unsupported case: $selected" >&2
    exit 2
  fi
  CASES+=("$selected")
}

set_cases() {
  local selected="$1"
  if [[ "$CASES_SELECTED" == "false" ]]; then
    CASES=()
    CASES_SELECTED="true"
  fi
  case "$selected" in
    search) CASES+=("${SEARCH_CASES[@]}") ;;
    data) CASES+=("${DATA_CASES[@]}") ;;
    platform) CASES+=("${PLATFORM_CASES[@]}") ;;
    templates) CASES+=("${TEMPLATE_CASES[@]}") ;;
    integrations) CASES+=("${INTEGRATION_CASES[@]}") ;;
    rollouts) CASES+=("${ROLLOUT_CASES[@]}") ;;
    all) CASES+=("${ALL_CASES[@]}") ;;
    *) add_case "$selected" ;;
  esac
}

case_file_for() {
  local case_name="$1"
  local slug="${case_name//-/_}"
  local case_file="tests/acceptance/cases/${slug}_workload.k"
  if [[ ! -f "$ROOT_DIR/framework/$case_file" ]]; then
    echo "Unsupported case: $case_name" >&2
    exit 2
  fi
  echo "$case_file"
}

namespace_for() {
  local case_name="$1"
  echo "idp-acceptance-${case_name}"
}

is_apply_case() {
  local case_name="$1"
  contains_case "$case_name" "${APPLY_CASES[@]}"
}

has_dry_run_only_cases() {
  local case_name
  for case_name in "${CASES[@]}"; do
    if ! is_apply_case "$case_name"; then
      return 0
    fi
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) shift; set_cases "${1:?missing case name}" ;;
    --cluster-name) shift; CLUSTER_NAME="${1:?missing cluster name}" ;;
    --kind-image) shift; KIND_IMAGE="${1:?missing kind image}" ;;
    --keep-cluster) KEEP_CLUSTER="true" ;;
    --keep-case-resources) KEEP_CASE_RESOURCES="true" ;;
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

install_dry_run_crds() {
  echo "==> Installing lightweight acceptance CRD stubs for server-side dry-run"
  kubectl apply -f "$ROOT_DIR/framework/tests/acceptance/crds/dry_run_crds.yaml"
  kubectl wait --for=condition=Established --timeout=120s -f "$ROOT_DIR/framework/tests/acceptance/crds/dry_run_crds.yaml"
}

apply_case() {
  local case_name="$1"
  local manifest_file="$2"
  # First pass: creates any Namespace objects (which render last in IDP YAML).
  # Namespaced resources that precede the Namespace doc may fail here; that is expected.
  kubectl apply -f "$manifest_file" 2>/dev/null || true
  # Second pass: all namespaces now exist.
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
    webapp-service-account-rollout)
      kubectl -n idp-acceptance-webapp-service-account-rollout rollout status deploy/acceptance-webapp-sa --timeout=180s
      kubectl -n idp-acceptance-webapp-service-account-rollout get deploy,svc,sa
      ;;
    webapp-database-stack-rollout)
      kubectl -n idp-acceptance-webapp-database-stack-rollout rollout status deploy/acceptance-stack-webapp --timeout=240s
      kubectl -n idp-acceptance-webapp-database-stack-rollout rollout status deploy/acceptance-stack-db --timeout=240s
      kubectl -n idp-acceptance-webapp-database-stack-rollout get deploy,svc,pvc,cm
      kubectl get pv acceptance-stack-db-pv
      ;;
    elasticsearch-kibana-stack-rollout)
      kubectl -n idp-acceptance-elasticsearch-kibana-stack-rollout rollout status statefulset/acceptance-elk-elasticsearch --timeout=240s
      kubectl -n idp-acceptance-elasticsearch-kibana-stack-rollout rollout status deploy/acceptance-elk-kibana --timeout=240s
      kubectl -n idp-acceptance-elasticsearch-kibana-stack-rollout get statefulset,deploy,svc,cm
      ;;
    elk-stack-rollout)
      kubectl -n idp-acceptance-elk-stack-rollout rollout status statefulset/acceptance-elk-es --timeout=240s
      kubectl -n idp-acceptance-elk-stack-rollout rollout status deploy/acceptance-elk-kibana --timeout=240s
      kubectl -n idp-acceptance-elk-stack-rollout rollout status deploy/acceptance-elk-logstash --timeout=240s
      kubectl -n idp-acceptance-elk-stack-rollout get statefulset,deploy,svc,cm
      ;;
    webapp-dataprepper-stack-rollout)
      kubectl -n idp-acceptance-webapp-dataprepper-stack-rollout rollout status deploy/acceptance-webapp-dp --timeout=180s
      kubectl -n idp-acceptance-webapp-dataprepper-stack-rollout rollout status deploy/acceptance-dp --timeout=180s
      kubectl -n idp-acceptance-webapp-dataprepper-stack-rollout get deploy,svc,cm
      ;;
    webapp-opensearch-dashboards-stack-rollout)
      kubectl -n idp-acceptance-webapp-opensearch-dashboards-stack-rollout rollout status deploy/acceptance-webapp-osd --timeout=180s
      kubectl -n idp-acceptance-webapp-opensearch-dashboards-stack-rollout rollout status deploy/acceptance-osd --timeout=180s
      kubectl -n idp-acceptance-webapp-opensearch-dashboards-stack-rollout get deploy,svc,cm
      ;;
    webapp-elk-stack-rollout)
      kubectl -n idp-acceptance-webapp-elk-stack-rollout rollout status deploy/acceptance-webapp-elk --timeout=180s
      kubectl -n idp-acceptance-webapp-elk-stack-rollout rollout status statefulset/acceptance-elk-es --timeout=240s
      kubectl -n idp-acceptance-webapp-elk-stack-rollout rollout status deploy/acceptance-elk-kibana --timeout=240s
      kubectl -n idp-acceptance-webapp-elk-stack-rollout get statefulset,deploy,svc,cm
      ;;
    dataprepper-elk-stack-rollout)
      kubectl -n idp-acceptance-dataprepper-elk-stack-rollout rollout status deploy/acceptance-dp-elk --timeout=180s
      kubectl -n idp-acceptance-dataprepper-elk-stack-rollout rollout status statefulset/acceptance-elk-dp-es --timeout=240s
      kubectl -n idp-acceptance-dataprepper-elk-stack-rollout rollout status deploy/acceptance-elk-dp-kibana --timeout=240s
      kubectl -n idp-acceptance-dataprepper-elk-stack-rollout get statefulset,deploy,svc,cm
      ;;
    webapp-dataprepper-elk-stack-rollout)
      kubectl -n idp-acceptance-webapp-dataprepper-elk-stack-rollout rollout status deploy/acceptance-webapp-full --timeout=180s
      kubectl -n idp-acceptance-webapp-dataprepper-elk-stack-rollout rollout status deploy/acceptance-dp-full --timeout=180s
      kubectl -n idp-acceptance-webapp-dataprepper-elk-stack-rollout rollout status statefulset/acceptance-es-full --timeout=240s
      kubectl -n idp-acceptance-webapp-dataprepper-elk-stack-rollout rollout status deploy/acceptance-kibana-full --timeout=240s
      kubectl -n idp-acceptance-webapp-dataprepper-elk-stack-rollout get statefulset,deploy,svc,cm
      ;;
    webapp-database-dataprepper-stack-rollout)
      kubectl -n idp-acceptance-webapp-database-dataprepper-stack-rollout rollout status deploy/acceptance-app-3tier --timeout=180s
      kubectl -n idp-acceptance-webapp-database-dataprepper-stack-rollout rollout status deploy/acceptance-db-3tier --timeout=180s
      kubectl -n idp-acceptance-webapp-database-dataprepper-stack-rollout rollout status deploy/acceptance-dp-3tier --timeout=180s
      kubectl -n idp-acceptance-webapp-database-dataprepper-stack-rollout get deploy,svc,pvc,cm
      kubectl get pv acceptance-db-3tier-pv
      ;;
  esac
}

cleanup_case_resources() {
  local case_name="$1"
  local manifest_file="$2"
  local namespace

  [[ "$KEEP_CASE_RESOURCES" == "true" ]] && return 0

  namespace="$(namespace_for "$case_name")"
  echo "==> Cleaning acceptance resources for case: $case_name"
  kubectl delete -f "$manifest_file" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete namespace "$namespace" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || \
    kubectl delete namespace "$namespace" --ignore-not-found --wait=false >/dev/null 2>&1 || true
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

if has_dry_run_only_cases; then
  install_dry_run_crds
fi

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

  cleanup_case_resources "$case_name" "$manifest_file"
done

echo "==> Acceptance checks complete"

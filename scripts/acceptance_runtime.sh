#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="idp-concept-runtime"
KIND_IMAGE="kindest/node:v1.33.0"
KEEP_CLUSTER="false"
KEEP_CASE_RESOURCES="false"
SKIP_CREATE="false"
PREFLIGHT_ONLY="false"
INSTALL_DEPENDENCIES="false"
TIMEOUT="900s"
CASES=("basic" "webapp" "database")
CASES_SELECTED="false"

# Pinned dependency versions. Keep these explicit; never use latest.
CNPG_VERSION="1.25.1"
KEYCLOAK_OPERATOR_VERSION="26.0.0"
OPENSEARCH_OPERATOR_CHART_VERSION="2.7.0"
STRIMZI_OPERATOR_VERSION="0.45.0"
MONGODB_OPERATOR_VERSION="0.12.0"
RABBITMQ_OPERATOR_VERSION="2.9.0"
REDIS_OPERATOR_CHART_VERSION="0.16.0"
ECK_VERSION="3.0.0"
FLUX_VERSION="2.4.0"
OTEL_OPERATOR_CHART_VERSION="0.75.0"
LONGHORN_CHART_VERSION="1.7.2"
FLUENT_OPERATOR_CHART_VERSION="3.1.0"

declare -A INSTALLED_DEPENDENCIES=()

RUNTIME_BASIC_CASES=("basic" "webapp" "database")
RUNTIME_CNPG_CASES=("postgresql")
RUNTIME_KEYCLOAK_POSTGRESQL_CASES=("keycloak-postgresql")
RUNTIME_OPENSEARCH_CASES=("opensearch")
RUNTIME_DATAPREPPER_OPENSEARCH_CASES=("dataprepper-opensearch")
RUNTIME_KAFKA_CASES=("kafka")
RUNTIME_MONGODB_CASES=("mongodb")
RUNTIME_RABBITMQ_CASES=("rabbitmq")
RUNTIME_REDIS_CASES=("redis" "redis-cluster")
RUNTIME_ROLLOUT_CASES=("dataprepper-rollout" "opensearch-dashboards-rollout" "elasticsearch-rollout" "kibana-rollout" "logstash-rollout" "webapp-probes-rollout" "webapp-service-account-rollout" "webapp-database-stack-rollout" "elasticsearch-kibana-stack-rollout" "elk-stack-rollout" "webapp-dataprepper-stack-rollout" "webapp-opensearch-dashboards-stack-rollout" "webapp-elk-stack-rollout" "dataprepper-elk-stack-rollout" "webapp-dataprepper-elk-stack-rollout" "webapp-database-dataprepper-stack-rollout" "fluentbit-native-rollout")
RUNTIME_SEARCH_CASES=("opensearch" "opensearch-dashboards" "dataprepper-opensearch" "elasticsearch" "kibana" "logstash" "elasticsearch-v9" "kibana-v9" "logstash-v9")
RUNTIME_DATA_CASES=("database" "postgresql" "mongodb" "rabbitmq" "redis" "redis-cluster" "kafka" "minio-tenant" "minio-helm" "questdb" "valkey")
RUNTIME_PLATFORM_CASES=("backstage" "observability" "opentelemetry" "fluentbit-native" "fluentbit-helm" "fluentbit-operator" "vault" "keycloak" "keycloak-postgresql" "openbao")
RUNTIME_STORAGE_CASES=("longhorn" "ceph" "persistence-longhorn" "persistence-ceph")
RUNTIME_INTEGRATION_CASES=("dataprepper-opensearch" "keycloak-postgresql" "persistence-longhorn" "persistence-ceph" "webapp-postgresql-stack" "webapp-kafka-stack" "webapp-rabbitmq-stack" "webapp-redis-stack" "webapp-mongodb-stack")
RUNTIME_WEBAPP_STACKS_CASES=("webapp-postgresql-stack" "webapp-kafka-stack" "webapp-rabbitmq-stack" "webapp-redis-stack" "webapp-mongodb-stack")
RUNTIME_ALL_CASES=("${RUNTIME_BASIC_CASES[@]}" "${RUNTIME_ROLLOUT_CASES[@]}" "${RUNTIME_SEARCH_CASES[@]}" "${RUNTIME_DATA_CASES[@]}" "${RUNTIME_PLATFORM_CASES[@]}" "${RUNTIME_STORAGE_CASES[@]}" "${RUNTIME_INTEGRATION_CASES[@]}")

usage() {
  cat <<'EOF_USAGE'
Usage: ./scripts/acceptance_runtime.sh [options]

Options:
  --case <name>            Run one case/group. Supported runtime groups:
                           runtime-basic, runtime-cnpg,
                           runtime-keycloak-postgresql, runtime-opensearch,
                           runtime-dataprepper-opensearch, runtime-kafka,
                           runtime-mongodb, runtime-rabbitmq, runtime-redis,
                           runtime-rollouts, runtime-webapp-stacks,
                           runtime-search, runtime-data,
                           runtime-platform, runtime-storage,
                           runtime-integrations, runtime-all.
                           Individual fixture names are also supported
                           (e.g. webapp-probes-rollout,
                           webapp-service-account-rollout,
                           webapp-database-stack-rollout,
                           elasticsearch-kibana-stack-rollout,
                           elk-stack-rollout,
                           webapp-dataprepper-stack-rollout,
                           webapp-opensearch-dashboards-stack-rollout,
                           webapp-elk-stack-rollout,
                           dataprepper-elk-stack-rollout,
                            fluentbit-native-rollout,
                           webapp-dataprepper-elk-stack-rollout,
                           webapp-database-dataprepper-stack-rollout,
                           webapp-postgresql-stack,
                           webapp-kafka-stack,
                           webapp-rabbitmq-stack,
                           webapp-redis-stack,
                           webapp-mongodb-stack).
                           Can be repeated.
  --install-dependencies   Install known pinned operators/controllers before apply.
                           Intended for disposable clusters.
  --cluster-name <n>       Kind cluster name (default: idp-concept-runtime)
  --kind-image <img>       Kind node image (default: kindest/node:v1.33.0)
  --timeout <duration>     kubectl wait/rollout timeout (default: 900s)
  --keep-cluster           Do not delete the kind cluster on exit
  --keep-case-resources    Do not delete each case's resources after it passes
  --skip-create            Reuse the current Kubernetes context
  --preflight-only         Check local tools and exit without creating a cluster
  -h, --help               Show this help

This runner performs real kubectl apply and readiness checks. It does not install
dry-run CRD stubs. Operator-backed cases require real operators/controllers.
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

unique_cases() {
  awk '!seen[$0]++'
}

case_file_for() {
  local case_name="$1"
  local slug="${case_name//-/_}"
  local case_file="tests/acceptance/cases/${slug}_workload.k"
  if [[ ! -f "$ROOT_DIR/framework/$case_file" ]]; then
    echo "Unsupported runtime case: $case_name" >&2
    exit 2
  fi
  echo "$case_file"
}

add_case() {
  local selected="$1"
  case_file_for "$selected" >/dev/null
  CASES+=("$selected")
}

set_cases() {
  local selected="$1"
  if [[ "$CASES_SELECTED" == "false" ]]; then
    CASES=()
    CASES_SELECTED="true"
  fi
  case "$selected" in
    runtime-basic) CASES+=("${RUNTIME_BASIC_CASES[@]}") ;;
    runtime-cnpg) CASES+=("${RUNTIME_CNPG_CASES[@]}") ;;
    runtime-keycloak-postgresql) CASES+=("${RUNTIME_KEYCLOAK_POSTGRESQL_CASES[@]}") ;;
    runtime-opensearch) CASES+=("${RUNTIME_OPENSEARCH_CASES[@]}") ;;
    runtime-dataprepper-opensearch) CASES+=("${RUNTIME_DATAPREPPER_OPENSEARCH_CASES[@]}") ;;
    runtime-kafka) CASES+=("${RUNTIME_KAFKA_CASES[@]}") ;;
    runtime-mongodb) CASES+=("${RUNTIME_MONGODB_CASES[@]}") ;;
    runtime-rabbitmq) CASES+=("${RUNTIME_RABBITMQ_CASES[@]}") ;;
    runtime-redis) CASES+=("${RUNTIME_REDIS_CASES[@]}") ;;
    runtime-rollouts) CASES+=("${RUNTIME_ROLLOUT_CASES[@]}") ;;
    runtime-webapp-stacks) CASES+=("${RUNTIME_WEBAPP_STACKS_CASES[@]}") ;;
    runtime-search) CASES+=("${RUNTIME_SEARCH_CASES[@]}") ;;
    runtime-data) CASES+=("${RUNTIME_DATA_CASES[@]}") ;;
    runtime-platform) CASES+=("${RUNTIME_PLATFORM_CASES[@]}") ;;
    runtime-storage) CASES+=("${RUNTIME_STORAGE_CASES[@]}") ;;
    runtime-integrations) CASES+=("${RUNTIME_INTEGRATION_CASES[@]}") ;;
    runtime-all) CASES+=("${RUNTIME_ALL_CASES[@]}") ;;
    *) add_case "$selected" ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) shift; set_cases "${1:?missing case name}" ;;
    --install-dependencies) INSTALL_DEPENDENCIES="true" ;;
    --cluster-name) shift; CLUSTER_NAME="${1:?missing cluster name}" ;;
    --kind-image) shift; KIND_IMAGE="${1:?missing kind image}" ;;
    --timeout) shift; TIMEOUT="${1:?missing timeout}" ;;
    --keep-cluster) KEEP_CLUSTER="true" ;;
    --keep-case-resources) KEEP_CASE_RESOURCES="true" ;;
    --skip-create) SKIP_CREATE="true" ;;
    --preflight-only) PREFLIGHT_ONLY="true" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

mapfile -t CASES < <(printf '%s\n' "${CASES[@]}" | unique_cases)

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
  if [[ "$INSTALL_DEPENDENCIES" == "true" ]]; then
    require_cmd helm || missing=1
  fi
  if [[ "$missing" -ne 0 ]]; then
    echo "Install missing tools before running runtime acceptance tests." >&2
    return 1
  fi
  if [[ "$SKIP_CREATE" == "false" ]] && ! docker info >/dev/null 2>&1; then
    echo "Docker is installed but not reachable by the current user/session." >&2
    return 1
  fi
}

cleanup() {
  if [[ "$KEEP_CLUSTER" == "false" && "$SKIP_CREATE" == "false" ]]; then
    kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
  fi
}

fetch_kcl_deps() {
  # Pre-warm the KCL dependency cache before rendering any cases.
  # When the cache is cold and stdout is a non-TTY (e.g. redirected to a file),
  # KCL writes "downloading '<pkg>' from '<registry>'" messages to stdout,
  # which would contaminate the YAML output file and cause kubectl apply to fail
  # with "yaml: line 2: mapping values are not allowed in this context".
  # Running `kcl mod update` first downloads all declared dependencies into the
  # local cache so subsequent `kcl run` calls produce clean YAML-only output.
  echo "==> Pre-fetching KCL dependencies..."
  (cd "$ROOT_DIR/framework" && kcl mod update >/dev/null 2>&1) || true
}

render_case() {
  local case_name="$1"
  local output_file="$2"
  local case_file
  case_file="$(case_file_for "$case_name")"
  (cd "$ROOT_DIR/framework" && kcl run "$case_file") > "$output_file"
}

namespace_for() {
  local case_name="$1"
  echo "idp-acceptance-${case_name}"
}

ensure_case_namespace() {
  local case_name="$1"
  local namespace
  namespace="$(namespace_for "$case_name")"
  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
}

wait_all_rollouts() {
  local namespace="$1"
  local resource
  for resource in $(kubectl -n "$namespace" get deploy,statefulset,daemonset -o name --ignore-not-found 2>/dev/null || true); do
    echo "==> Waiting for rollout: $resource in $namespace"
    kubectl -n "$namespace" rollout status "$resource" --timeout="$TIMEOUT"
  done
}

wait_condition() {
  local namespace="$1"
  local resource="$2"
  local condition="${3:-Ready}"
  echo "==> Waiting for condition=$condition: $resource in $namespace"
  kubectl -n "$namespace" wait --for="condition=$condition" "$resource" --timeout="$TIMEOUT"
}

wait_exists() {
  local namespace="$1"
  local resource="$2"
  echo "==> Checking resource exists: $resource in $namespace"
  kubectl -n "$namespace" get "$resource"
}

wait_all_pvcs_bound() {
  local namespace="$1"
  local pvc
  for pvc in $(kubectl -n "$namespace" get pvc -o name --ignore-not-found 2>/dev/null || true); do
    echo "==> Waiting for PVC Bound: $pvc in $namespace"
    kubectl -n "$namespace" wait --for=jsonpath='{.status.phase}'=Bound "$pvc" --timeout="$TIMEOUT"
  done
}

wait_any_deployment_in_namespace() {
  local namespace="$1"
  kubectl -n "$namespace" wait --for=condition=Available deploy --all --timeout="$TIMEOUT"
}

helm_repo_add_update() {
  local name="$1"
  local url="$2"
  helm repo add "$name" "$url" >/dev/null 2>&1 || true
  helm repo update "$name" >/dev/null
}

install_once() {
  local key="$1"; shift
  if [[ "${INSTALLED_DEPENDENCIES[$key]:-false}" == "true" ]]; then
    echo "==> Dependency already installed in this run: $key"
    return 0
  fi
  "$@"
  INSTALLED_DEPENDENCIES["$key"]="true"
}

install_cnpg() {
  echo "==> Installing CloudNativePG ${CNPG_VERSION}"
  kubectl apply --server-side -f "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-${CNPG_VERSION}.yaml"
  kubectl -n cnpg-system rollout status deploy/cnpg-controller-manager --timeout="$TIMEOUT"
}

install_keycloak_operator() {
  echo "==> Installing Keycloak Operator ${KEYCLOAK_OPERATOR_VERSION}"
  kubectl apply -f "https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${KEYCLOAK_OPERATOR_VERSION}/kubernetes/kubernetes.yml"
  wait_any_deployment_in_namespace keycloak-system
}

install_opensearch_operator() {
  echo "==> Installing OpenSearch Operator chart ${OPENSEARCH_OPERATOR_CHART_VERSION}"
  helm_repo_add_update opensearch-operator https://opensearch-project.github.io/opensearch-k8s-operator/
  helm upgrade --install opensearch-operator opensearch-operator/opensearch-operator \
    --namespace opensearch-operator-system --create-namespace \
    --version "$OPENSEARCH_OPERATOR_CHART_VERSION" --wait --timeout "$TIMEOUT"
  wait_any_deployment_in_namespace opensearch-operator-system
}

install_strimzi() {
  echo "==> Installing Strimzi Kafka Operator ${STRIMZI_OPERATOR_VERSION}"
  helm_repo_add_update strimzi https://strimzi.io/charts/
  helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
    --namespace strimzi-system --create-namespace \
    --version "$STRIMZI_OPERATOR_VERSION" --wait --timeout "$TIMEOUT"
  wait_any_deployment_in_namespace strimzi-system
}

install_mongodb_operator() {
  echo "==> Installing MongoDB Community Operator ${MONGODB_OPERATOR_VERSION}"
  kubectl apply -k "github.com/mongodb/mongodb-kubernetes-operator/config/default?ref=v${MONGODB_OPERATOR_VERSION}"
  wait_any_deployment_in_namespace mongodb
}

install_rabbitmq_operator() {
  echo "==> Installing RabbitMQ Cluster Operator ${RABBITMQ_OPERATOR_VERSION}"
  kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/download/v${RABBITMQ_OPERATOR_VERSION}/cluster-operator.yml"
  wait_any_deployment_in_namespace rabbitmq-system
}

install_redis_operator() {
  echo "==> Installing Redis Operator chart ${REDIS_OPERATOR_CHART_VERSION}"
  helm_repo_add_update ot-helm https://ot-container-kit.github.io/helm-charts/
  helm upgrade --install redis-operator ot-helm/redis-operator \
    --namespace redis-operator --create-namespace \
    --version "$REDIS_OPERATOR_CHART_VERSION" --wait --timeout "$TIMEOUT"
  wait_any_deployment_in_namespace redis-operator
}

install_eck() {
  echo "==> Installing ECK ${ECK_VERSION}"
  kubectl apply -f "https://download.elastic.co/downloads/eck/${ECK_VERSION}/crds.yaml"
  kubectl apply -f "https://download.elastic.co/downloads/eck/${ECK_VERSION}/operator.yaml"
  wait_any_deployment_in_namespace elastic-system
}

install_flux() {
  echo "==> Installing Flux controllers ${FLUX_VERSION}"
  kubectl apply -f "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/install.yaml"
  wait_any_deployment_in_namespace flux-system
}

install_otel_operator() {
  echo "==> Installing OpenTelemetry Operator chart ${OTEL_OPERATOR_CHART_VERSION}"
  helm_repo_add_update open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
  helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
    --namespace opentelemetry-operator-system --create-namespace \
    --version "$OTEL_OPERATOR_CHART_VERSION" --wait --timeout "$TIMEOUT" \
    --set admissionWebhooks.certManager.enabled=false \
    --set admissionWebhooks.autoGenerateCert.enabled=true
  wait_any_deployment_in_namespace opentelemetry-operator-system
}

install_longhorn() {
  echo "==> Installing Longhorn chart ${LONGHORN_CHART_VERSION}"
  helm_repo_add_update longhorn https://charts.longhorn.io
  helm upgrade --install longhorn longhorn/longhorn \
    --namespace longhorn-system --create-namespace \
    --version "$LONGHORN_CHART_VERSION" --wait --timeout "$TIMEOUT" \
    --set defaultSettings.defaultReplicaCount=1
  wait_any_deployment_in_namespace longhorn-system
}

install_fluent_operator() {
  echo "==> Installing Fluent Operator chart ${FLUENT_OPERATOR_CHART_VERSION}"
  helm_repo_add_update fluent https://fluent.github.io/helm-charts
  helm upgrade --install fluent-operator fluent/fluent-operator \
    --namespace fluent-operator --create-namespace \
    --version "$FLUENT_OPERATOR_CHART_VERSION" --wait --timeout "$TIMEOUT"
  wait_any_deployment_in_namespace fluent-operator
}

install_dependencies_for_case() {
  local case_name="$1"
  [[ "$INSTALL_DEPENDENCIES" == "true" ]] || return 0

  case "$case_name" in
    postgresql) install_once cnpg install_cnpg ;;
    keycloak) install_once keycloak install_keycloak_operator ;;
    keycloak-postgresql) install_once cnpg install_cnpg; install_once keycloak install_keycloak_operator ;;
    opensearch|dataprepper-opensearch) install_once opensearch install_opensearch_operator ;;
    kafka) install_once strimzi install_strimzi ;;
    mongodb) install_once mongodb install_mongodb_operator ;;
    rabbitmq) install_once rabbitmq install_rabbitmq_operator ;;
    redis|redis-cluster) install_once redis install_redis_operator ;;
    elasticsearch-v9|kibana-v9|logstash-v9) install_once eck install_eck ;;
    opentelemetry) install_once flux install_flux; install_once opentelemetry install_otel_operator ;;
    longhorn|persistence-longhorn) install_once flux install_flux; install_once longhorn install_longhorn ;;
    ceph|persistence-ceph) install_once flux install_flux ;;
    backstage|observability|minio-helm|questdb|valkey|openbao|fluentbit-helm) install_once flux install_flux ;;
    fluentbit-operator) install_once flux install_flux; install_once fluent-operator install_fluent_operator ;;
    webapp-postgresql-stack) install_once cnpg install_cnpg ;;
    webapp-kafka-stack) install_once strimzi install_strimzi ;;
    webapp-rabbitmq-stack) install_once rabbitmq install_rabbitmq_operator ;;
    webapp-redis-stack) install_once redis install_redis_operator ;;
    webapp-mongodb-stack) install_once mongodb install_mongodb_operator ;;
    *) ;;
  esac
}

cleanup_case_resources() {
  local case_name="$1"
  local manifest_file="$2"
  local namespace

  [[ "$KEEP_CASE_RESOURCES" == "true" ]] && return 0

  namespace="$(namespace_for "$case_name")"
  echo "==> Cleaning runtime resources for case: $case_name"
  kubectl delete -f "$manifest_file" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete namespace "$namespace" --ignore-not-found --wait=true --timeout=180s >/dev/null 2>&1 || \
    kubectl delete namespace "$namespace" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

apply_case_manifest() {
  local case_name="$1"
  local manifest_file="$2"
  echo "==> Applying runtime manifest: $case_name"
  ensure_case_namespace "$case_name"
  # First pass: creates any Namespace objects (which render last in IDP YAML).
  # Namespaced resources that precede the Namespace doc may fail here; that is expected.
  kubectl apply -f "$manifest_file" 2>/dev/null || true
  # Second pass: all namespaces now exist, remaining resources apply successfully.
  kubectl apply -f "$manifest_file"
}

wait_case() {
  local case_name="$1"
  local namespace
  namespace="$(namespace_for "$case_name")"

  case "$case_name" in
    basic)
      kubectl -n idp-acceptance-basic rollout status deploy/acceptance-pause --timeout="$TIMEOUT"
      kubectl -n idp-acceptance-basic get deploy,svc,cm
      ;;
    webapp)
      kubectl -n idp-acceptance-webapp rollout status deploy/acceptance-webapp --timeout="$TIMEOUT"
      kubectl -n idp-acceptance-webapp get deploy,svc,cm
      ;;
    database)
      kubectl -n idp-acceptance-database rollout status deploy/acceptance-db --timeout="$TIMEOUT"
      wait_all_pvcs_bound idp-acceptance-database
      kubectl -n idp-acceptance-database get deploy,svc,pvc
      ;;
    dataprepper)
      kubectl -n idp-acceptance-dataprepper rollout status deploy/data-prepper --timeout="$TIMEOUT"
      ;;
    dataprepper-rollout|opensearch-dashboards-rollout|elasticsearch-rollout|kibana-rollout|logstash-rollout|webapp-probes-rollout|webapp-service-account-rollout|elasticsearch-kibana-stack-rollout|elk-stack-rollout|webapp-dataprepper-stack-rollout|webapp-opensearch-dashboards-stack-rollout|webapp-elk-stack-rollout|dataprepper-elk-stack-rollout|webapp-dataprepper-elk-stack-rollout|fluentbit-native-rollout)
      wait_all_rollouts "$namespace"
      wait_all_pvcs_bound "$namespace"
      ;;
    webapp-database-stack-rollout)
      kubectl -n "$namespace" rollout status deploy/acceptance-stack-webapp --timeout="$TIMEOUT"
      kubectl -n "$namespace" rollout status deploy/acceptance-stack-db --timeout="$TIMEOUT"
      wait_all_pvcs_bound "$namespace"
      kubectl -n "$namespace" get deploy,svc,pvc,cm
      ;;
    webapp-database-dataprepper-stack-rollout)
      kubectl -n "$namespace" rollout status deploy/acceptance-app-3tier --timeout="$TIMEOUT"
      kubectl -n "$namespace" rollout status deploy/acceptance-db-3tier --timeout="$TIMEOUT"
      kubectl -n "$namespace" rollout status deploy/acceptance-dp-3tier --timeout="$TIMEOUT"
      wait_all_pvcs_bound "$namespace"
      kubectl -n "$namespace" get deploy,svc,pvc,cm
      ;;
    elasticsearch-kibana-stack-rollout)
      kubectl -n "$namespace" rollout status statefulset/acceptance-elk-elasticsearch --timeout="$TIMEOUT"
      kubectl -n "$namespace" rollout status deploy/acceptance-elk-kibana --timeout="$TIMEOUT"
      wait_all_rollouts "$namespace"
      kubectl -n "$namespace" get statefulset,deploy,svc,cm
      ;;
    elk-stack-rollout)
      kubectl -n "$namespace" rollout status statefulset/acceptance-elk-es --timeout="$TIMEOUT"
      kubectl -n "$namespace" rollout status deploy/acceptance-elk-kibana --timeout="$TIMEOUT"
      kubectl -n "$namespace" rollout status deploy/acceptance-elk-logstash --timeout="$TIMEOUT"
      wait_all_rollouts "$namespace"
      kubectl -n "$namespace" get statefulset,deploy,svc,cm
      ;;
    webapp-dataprepper-stack-rollout)
      kubectl -n "$namespace" rollout status deploy/acceptance-webapp-dp --timeout="$TIMEOUT"
      kubectl -n "$namespace" rollout status deploy/acceptance-dp --timeout="$TIMEOUT"
      kubectl -n "$namespace" get deploy,svc,cm
      ;;
    dataprepper-opensearch)
      wait_condition "$namespace" opensearchcluster.opensearch.org/acceptance-opensearch Ready
      kubectl -n "$namespace" rollout status deploy/acceptance-dataprepper --timeout="$TIMEOUT"
      ;;
    opensearch)
      wait_condition "$namespace" opensearchcluster.opensearch.org/acceptance-opensearch Ready
      ;;
    opensearch-dashboards|elasticsearch|kibana|logstash)
      wait_all_rollouts "$namespace"
      ;;
    elasticsearch-v9)
      wait_condition "$namespace" elasticsearch.elasticsearch.k8s.elastic.co/acceptance-elasticsearch-v9 Ready
      ;;
    kibana-v9)
      wait_condition "$namespace" kibana.kibana.k8s.elastic.co/acceptance-kibana-v9 Ready
      ;;
    logstash-v9)
      wait_condition "$namespace" logstash.logstash.k8s.elastic.co/acceptance-logstash-v9 Ready
      ;;
    postgresql)
      wait_condition "$namespace" cluster.postgresql.cnpg.io/acceptance-postgresql Ready
      ;;
    keycloak)
      wait_condition "$namespace" keycloak.k8s.keycloak.org/acceptance-keycloak Ready
      ;;
    keycloak-postgresql)
      wait_condition "$namespace" cluster.postgresql.cnpg.io/acceptance-keycloak-postgresql Ready
      wait_condition "$namespace" keycloak.k8s.keycloak.org/acceptance-keycloak Ready
      ;;
    kafka)
      wait_condition "$namespace" kafka.kafka.strimzi.io/acceptance-kafka Ready
      ;;
    mongodb)
      wait_condition "$namespace" mongodbcommunity.mongodbcommunity.mongodb.com/acceptance-mongodb Ready
      ;;
    rabbitmq)
      wait_condition "$namespace" rabbitmqcluster.rabbitmq.com/acceptance-rabbitmq AllReplicasReady
      ;;
    redis)
      wait_condition "$namespace" redis.redis.redis.opstreelabs.in/acceptance-redis Ready
      ;;
    redis-cluster)
      wait_condition "$namespace" rediscluster.redis.redis.opstreelabs.in/acceptance-redis-cluster Ready
      ;;
    webapp-postgresql-stack)
      kubectl -n "$namespace" rollout status deploy/acceptance-webapp-pg --timeout="$TIMEOUT"
      wait_condition "$namespace" cluster.postgresql.cnpg.io/acceptance-postgresql-stack Ready
      ;;
    webapp-kafka-stack)
      kubectl -n "$namespace" rollout status deploy/acceptance-webapp-kafka --timeout="$TIMEOUT"
      wait_condition "$namespace" kafka.kafka.strimzi.io/acceptance-kafka-stack Ready
      ;;
    webapp-rabbitmq-stack)
      kubectl -n "$namespace" rollout status deploy/acceptance-webapp-rmq --timeout="$TIMEOUT"
      wait_condition "$namespace" rabbitmqcluster.rabbitmq.com/acceptance-rabbitmq-stack AllReplicasReady
      ;;
    webapp-redis-stack)
      kubectl -n "$namespace" rollout status deploy/acceptance-webapp-redis --timeout="$TIMEOUT"
      wait_condition "$namespace" redis.redis.redis.opstreelabs.in/acceptance-redis-stack Ready
      ;;
    webapp-mongodb-stack)
      kubectl -n "$namespace" rollout status deploy/acceptance-webapp-mongo --timeout="$TIMEOUT"
      wait_condition "$namespace" mongodbcommunity.mongodbcommunity.mongodb.com/acceptance-mongodb-stack Ready
      ;;
    minio-tenant)
      wait_condition "$namespace" tenant.minio.min.io/acceptance-minio Ready
      ;;
    backstage|questdb|minio-helm|valkey|openbao|longhorn|ceph)
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/acceptance-${case_name} Ready
      wait_all_rollouts "$namespace"
      wait_all_pvcs_bound "$namespace"
      ;;
    observability)
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/acceptance-prometheus Ready
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/acceptance-grafana Ready
      wait_exists "$namespace" servicemonitor.monitoring.coreos.com/acceptance-service-monitor
      ;;
    opentelemetry)
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/acceptance-otel-operator Ready
      wait_condition "$namespace" opentelemetrycollector.opentelemetry.io/acceptance-otel-collector Ready
      wait_exists "$namespace" instrumentation.opentelemetry.io/acceptance-instrumentation
      ;;
    fluentbit-native)
      wait_all_rollouts "$namespace"
      kubectl -n "$namespace" get deploy,svc,cm
      ;;
    fluentbit-helm)
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/acceptance-fluentbit Ready
      wait_all_rollouts "$namespace"
      ;;
    fluentbit-operator)
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/fluent-operator Ready
      wait_exists "$namespace" fluentbit.fluentbit.fluent.io/acceptance-fluentbit
      ;;
    vault)
      wait_condition "$namespace" vaultconnection.secrets.hashicorp.com/acceptance-vault-connection Ready
      wait_condition "$namespace" vaultauth.secrets.hashicorp.com/acceptance-vault-auth Ready
      wait_condition "$namespace" vaultstaticsecret.secrets.hashicorp.com/acceptance-vault-static-secret Ready
      ;;
    persistence-longhorn)
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/acceptance-longhorn Ready
      wait_all_pvcs_bound "$namespace"
      ;;
    persistence-ceph)
      wait_condition "$namespace" helmrelease.helm.toolkit.fluxcd.io/acceptance-ceph Ready
      wait_condition "$namespace" cephcluster.ceph.rook.io/acceptance-ceph Ready
      wait_all_pvcs_bound "$namespace"
      ;;
    *)
      echo "No runtime wait rule for case: $case_name" >&2
      return 1
      ;;
  esac
}

preflight
if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  echo "Runtime preflight OK. Required tools are available for the selected mode."
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

fetch_kcl_deps

for case_name in "${CASES[@]}"; do
  echo "==> Runtime acceptance case: $case_name"
  install_dependencies_for_case "$case_name"

  manifest_file="$TMP_DIR/${case_name}.yaml"
  echo "==> Rendering via IDP path: $case_name"
  render_case "$case_name" "$manifest_file"

  apply_case_manifest "$case_name" "$manifest_file"

  echo "==> Waiting for real runtime readiness: $case_name"
  wait_case "$case_name"

  cleanup_case_resources "$case_name" "$manifest_file"
done

echo "==> Runtime acceptance checks complete"




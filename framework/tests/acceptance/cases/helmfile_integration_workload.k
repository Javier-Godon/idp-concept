"""
Acceptance fixture: Helmfile integration testing with real Helm chart validation.

This fixture exercises the Helmfile procedure with full helm tooling integration:
  1. Generate Helmfile output from a reference stack
  2. Validate Helmfile syntax (helmfile lint)
  3. Template each Helm chart (helm template)
  4. Validate templated manifests (kubeconform/kubeval)
  5. Verify dependency ordering (needs entries resolvable)
  6. Audit chart metadata (versions pinned, repos accessible)

Validates:
- Helmfile YAML is valid and structured correctly
- All referenced Helm charts exist with correct versions
- Template values are injected without errors
- Manifest output passes K8s schema validation
- Release dependencies (needs) form a valid DAG
- No floating tags (all versions pinned)
- Repository URLs are accessible (dry-run compatible check)

This is primarily a **dry-run** fixture with optional `helm template` integration.
Use in: scripts/acceptance_kind.sh --case helmfile-integration
        scripts/acceptance_runtime.sh for full helm template validation (optional)
"""

import manifests
import templates.webapp.v1_0_0.webapp as webapp
import templates.postgresql.v1_0_0.postgresql as postgresql
import templates.redis.v1_0_0.redis as redis
import templates.kafka.v1_0_0.kafka as kafka
import models.manifests.renderstack as rs
import models.metadata as meta
import custom.helmfile.helmfile as hf
import procedures.kcl_to_helmfile as helmfile_proc

_namespace = "idp-acceptance-helmfile-integration"

# Multi-component stack to exercise complex release dependencies
_redis = redis.RedisModule {
    name = "acceptance-helmfile-redis"
    namespace = _namespace
    configurations = {}
    asset = { version = "7.0" }
    redisName = "acceptance-helmfile-redis"
    storageSize = "256Mi"
    storageClassName = ""
    dependsOn = []
}.instance

_db = postgresql.PostgreSQLClusterModule {
    name = "acceptance-helmfile-postgres"
    namespace = _namespace
    configurations = {}
    asset = { version = "16" }
    clusterName = "acceptance-helmfile-postgres"
    instances = 1
    storageSize = "256Mi"
    storageClass = ""
    dependsOn = []
}.instance

# App depends on both database and cache
_app = webapp.WebAppModule {
    name = "acceptance-helmfile-app"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    port = 8080
    replicas = 1
    configData = {
        "application.yaml" = """
redis:
  host: acceptance-helmfile-redis
  port: 6379
database:
  host: acceptance-helmfile-postgres
  port: 5432
"""
    }
    env = [
        {name = "REDIS_HOST", value = "acceptance-helmfile-redis"}
        {name = "DB_HOST", value = "acceptance-helmfile-postgres"}
    ]
    dependsOn = [_redis, _db]
}.instance

# Kafka as an independent accessory (no deps on above)
_kafka = kafka.KafkaClusterModule {
    name = "acceptance-helmfile-kafka"
    namespace = _namespace
    configurations = {}
    asset = { version = "1.0" }
    clusterName = "acceptance-helmfile-kafka"
    kafkaVersion = "3.5.0"
    kafkaReplicas = 1
    zookeeperReplicas = 1
    storageSize = "256Mi"
    topics = [
        {name = "events", partitions = 3, replicas = 1}
        {name = "logs", partitions = 1, replicas = 1}
    ]
    dependsOn = []
}.instance

_stack = rs.RenderStack {
    instanceConfigurations = {}
    components = [_app]
    accessories = [_redis, _db, _kafka]
    k8snamespaces = []
    metadata = meta.Metadata {
        owner = "platform-team"
        team = "platform"
        lifecycle = "experimental"
        tier = "2"
        runbook = "https://wiki/helmfile-integration-test"
        support = "platform@example.com"
    }
    helmfile = hf.HelmfileRenderOptions {
        chartBasePath = "./charts"
        includeGeneratedReleases = True
        repositories = [
            hf.Repository {
                name = "bitnami"
                url = "https://charts.bitnami.com/bitnami"
            }
            hf.Repository {
                name = "strimzi"
                url = "https://strimzi.io/charts"
            }
        ]
        environments = {
            acceptance = hf.Environment {
                values = ["environments/acceptance.yaml"]
            }
        }
        helmDefaults = hf.HelmDefaults {
            wait = True
            timeout = 300
            atomic = True
            force = False
        }
        releaseDefaults = hf.ReleasePatch {
            createNamespace = True
            atomic = True
        }
        # Per-module overrides can customize chart sources, versions, values
        releaseOverrides = {
            "acceptance-helmfile-kafka" = hf.ReleasePatch {
                chart = "strimzi/strimzi-kafka-operator"
                version = "0.39.0"
            }
        }
    }
}

_helmfile = helmfile_proc.generate_helmfile_from_stack(_stack, "./charts")

manifests.yaml_stream([_helmfile])







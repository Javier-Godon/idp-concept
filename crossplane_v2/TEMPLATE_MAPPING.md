# Framework Templates ↔ Crossplane Managed Resources Mapping

**Purpose**: Understand the relationship between framework template generators and hand-authored Crossplane platform APIs.

**Last Updated**: June 7, 2026

---

## Core Concept: Two Tracks, Not 1:1 Mirrors

| Aspect | Framework Templates | Crossplane Managed Resources |
|--------|-------------------|---------------------------|
| **Purpose** | Generate Kubernetes manifests in 9 output formats (YAML, Helm, Kusion, etc.) | Provide intent-level APIs for platform infrastructure control-plane |
| **Authored How** | Auto-generated from KCL module schemas | Hand-authored per resource |
| **Cardinality** | ~23 templates (webapp, databases, infrastructure, third-party) | 23 complete curated APIs (all infrastructure) |
| **Scope** | Includes application workloads + infrastructure | Platform/infrastructure only (exclude app workloads) |
| **Update Cycle** | Template-driven (render → output format) | Manual (Composition updates required) |
| **Status** | Dynamic (updated per release) | ✅ Complete (100% parity with infrastructure templates)

### Selection Policy

**Include in `crossplane_v2/managed_resources/`**: Platform/infrastructure domain services that benefit from intent-level self-service APIs with ongoing lifecycle management.

**Exclude**: Application workloads (WebAppModule, generic SingleDatabaseModule) stay on Tier-1 GitOps/YAML path.

---

## Template-to-Managed-Resource Mapping

### ✅ Mapped (Crossplane API Available)

| Framework Template | Location | Crossplane API | Managed Resource | Status | Notes |
|---|---|---|---|---|---|
| **PostgreSQL (CNPG)** | `framework/templates/postgresql/` | `XPostgresInstance` | `crossplane_v2/managed_resources/postgres/` | ✅ Complete | Hand-authored before this effort |
| **Kafka (Strimzi)** | `framework/templates/kafka/v1_0_0/kafka.k` | `XKafkaStrimzi` | `crossplane_v2/managed_resources/kafka_strimzi/` | ✅ Complete | Hand-authored before this effort |
| **Keycloak** | `framework/templates/keycloak/` | `XKeycloak` | `crossplane_v2/managed_resources/keycloak/` | ✅ Complete | Hand-authored before this effort |
| **MongoDB Community** | `framework/templates/mongodb/v1_0_0/mongodb.k` | `XMongoDBInstance` | `crossplane_v2/managed_resources/mongodb/` | ✅ New | Implemented June 4, 2026 |
| **RabbitMQ Cluster** | `framework/templates/rabbitmq/v1_0_0/rabbitmq.k` | `XRabbitMQCluster` | `crossplane_v2/managed_resources/rabbitmq/` | ✅ New | Implemented June 4, 2026 |
| **Redis / RedisCluster** | `framework/templates/redis/v1_0_0/redis.k` | `XRedisInstance` | `crossplane_v2/managed_resources/redis/` | ✅ New | Dual-mode (standalone/cluster); June 4, 2026 |
| **OpenSearch** | `framework/templates/opensearch/v2_17_0/opensearch.k` | `XOpenSearchCluster` | `crossplane_v2/managed_resources/opensearch/` | ✅ New | Includes Dashboards; June 4, 2026 |
| **MinIO Tenant** | `framework/templates/minio/v1_0_0/minio.k` | `XMinIOTenant` | `crossplane_v2/managed_resources/minio/` | ✅ New | Operator archived March 2026; Helm recommended; June 4, 2026 |
| **Vault Secrets Operator** | `framework/templates/vault/v1_0_0/vault.k` | `XVaultInstance` | `crossplane_v2/managed_resources/vault/` | ✅ New | BUSL-1.1; alternatives available; June 4, 2026 |
| **QuestDB** | `framework/templates/questdb/v1_0_0/questdb.k` | `XQuestDBInstance` | `crossplane_v2/managed_resources/questdb/` | ✅ New | Helm chart; no operator; June 4, 2026 |
| **Elasticsearch** | `framework/templates/elastic/v9_4_1/elasticsearch.k` | `XElasticsearchCluster` | `crossplane_v2/managed_resources/elastic/` | ✅ New | ECK-based (v9+); June 4, 2026 |
| **Kibana** | `framework/templates/elastic/v9_4_1/kibana.k` | `XKibanaInstance` | `crossplane_v2/managed_resources/elastic/` | ✅ Complete | ECK-based; June 4, 2026 |
| **Logstash** | `framework/templates/elastic/v9_4_1/logstash.k` | `XLogstashInstance` | `crossplane_v2/managed_resources/elastic/` | ✅ Complete | ECK-based; June 4, 2026 |
| **OpenTelemetry Collector** | `framework/templates/opentelemetry/v1_0_0/opentelemetry.k` | `XOpenTelemetryCollector` | `crossplane_v2/managed_resources/opentelemetry/` | ✅ Complete | Helm operator; June 4, 2026 |
| **Data Prepper** | `framework/templates/dataprepper/v1_0_0/dataprepper.k` | `XDataPrepperPipeline` | `crossplane_v2/managed_resources/dataprepper/` | ✅ Complete | K8s-native (no operator); June 4, 2026 |
| **Valkey** | `framework/templates/valkey/v1_0_0/valkey.k` | `XValkeyInstance` | `crossplane_v2/managed_resources/valkey/` | ✅ Complete | Redis-compatible; OT Operator; June 4, 2026 |
| **OpenBao** | `framework/templates/openbao/v1_0_0/openbao.k` | `XOpenBaoInstance` | `crossplane_v2/managed_resources/openbao/` | ✅ Complete | Helm (Apache 2.0); June 4, 2026 |
| **Fluent Bit** | `framework/templates/fluentbit/v3_2_10/fluentbit.k` | `XFluentBitInstance` | `crossplane_v2/managed_resources/fluentbit/` | ✅ Complete | K8s-native log collection; June 4, 2026 |
| **Timescale** | `framework/templates/timescale/v1_0_0/timescale.k` | `XTimescaleDBInstance` | `crossplane_v2/managed_resources/timescale/` | ✅ New | PostgreSQL + TimescaleDB extension; CNPG; June 7, 2026 |
| **Ceph (Rook)** | `framework/templates/ceph/v1_0_0/ceph.k` | `XCephCluster` | `crossplane_v2/managed_resources/ceph/` | ✅ New | Distributed storage; Rook+Helm; June 7, 2026 |
| **Longhorn** | `framework/templates/longhorn/v1_0_0/longhorn.k` | `XLonghornInstance` | `crossplane_v2/managed_resources/longhorn/` | ✅ New | Block storage; Helm; June 7, 2026 |
| **Observability Stack** | `framework/templates/observability/v1_0_0/observability.k` | `XObservabilityProvisioner` | `crossplane_v2/managed_resources/observability/` | ✅ New | Prometheus + Grafana + Alertmanager; Helm composite; June 7, 2026 |
| **Cert-Manager** | `framework/templates/cert_manager/v1_0_0/cert_manager.k` | `XCertManager` | `crossplane_v2/managed_resources/cert_manager/` | ✅ Complete | Certificate management; ACME; June 7, 2026 |
| **External-DNS** | `framework/templates/external_dns/v1_0_0/external_dns.k` | `XExternalDNS` | `crossplane_v2/managed_resources/external_dns/` | ✅ New | Automatic DNS management; June 7, 2026 |
| **Gateway API** | `framework/templates/gateway_api/v1_0_0/gateway_api.k` | `XGateway` | `crossplane_v2/managed_resources/gateway_api/` | ✅ New | Modern API Gateway (Envoy/NGINX/Istio); June 7, 2026 |
| **Network Policies** | `framework/templates/network_policies/v1_0_0/network_policies.k` | `XNetworkPolicies` | `crossplane_v2/managed_resources/network_policies/` | ✅ New | Kubernetes network isolation; June 7, 2026 |
| **Apache APISIX** | `framework/templates/apisix/v1_0_0/apisix.k` | `XAPIGateway` | `crossplane_v2/managed_resources/apisix/` | ✅ New | Cloud-native API gateway; Helm; June 7, 2026 |
| **Apache Superset** | `framework/templates/superset/v1_0_0/superset.k` | `XSuperset` | `crossplane_v2/managed_resources/superset/` | ✅ New | Data visualization & BI platform; Helm; June 7, 2026 |
| **Power BI Connector** | `framework/templates/powerbi/v1_0_0/powerbi_connector.k` | `XPowerBIConnector` | `crossplane_v2/managed_resources/powerbi/` | ✅ New | Integration helper for QuestDB/Superset connection; ConfigMap-based; June 7, 2026 |

### ✅ Phase 3 Implementations (NEW — June 7, 2026)

**Status**: All infrastructure services now have complete mapping!

| Framework Template | Location | Crossplane API | Managed Resource | Status | Notes |
|---|---|---|---|---|---|
| **Timescale** | `framework/templates/timescale/v1_0_0/timescale.k` | `XTimescaleDBInstance` | `crossplane_v2/managed_resources/timescale/` | ✅ Complete | PostgreSQL with TimescaleDB extension (CNPG) |
| **Ceph (Rook)** | `framework/templates/ceph/v1_0_0/ceph.k` | `XCephCluster` | `crossplane_v2/managed_resources/ceph/` | ✅ Complete | Distributed block storage; Tier 0 infrastructure |
| **Longhorn** | `framework/templates/longhorn/v1_0_0/longhorn.k` | `XLonghornInstance` | `crossplane_v2/managed_resources/longhorn/` | ✅ Complete | Lightweight distributed storage; Tier 1 |
| **Observability** | `framework/templates/observability/v1_0_0/observability.k` | `XObservabilityProvisioner` | `crossplane_v2/managed_resources/observability/` | ✅ Complete | Prometheus + Grafana + Alertmanager composite |
| **Cert-Manager** | `framework/templates/cert_manager/v1_0_0/cert_manager.k` | `XCertManager` | `crossplane_v2/managed_resources/cert_manager/` | ✅ Complete | ACME certificate provisioning and renewal |
| **External-DNS** | `framework/templates/external_dns/v1_0_0/external_dns.k` | `XExternalDNS` | `crossplane_v2/managed_resources/external_dns/` | ✅ Complete | Automatic DNS record management (AWS/Azure/GCP/Cloudflare) |
| **Gateway API** | `framework/templates/gateway_api/v1_0_0/gateway_api.k` | `XGateway` | `crossplane_v2/managed_resources/gateway_api/` | ✅ Complete | Modern API Gateway controller (Envoy/NGINX/Istio) instead of legacy Ingress |
| **Network Policies** | `framework/templates/network_policies/v1_0_0/network_policies.k` | `XNetworkPolicies` | `crossplane_v2/managed_resources/network_policies/` | ✅ Complete | Zero-trust networking with Kubernetes NetworkPolicy |
| **Apache APISIX** | `framework/templates/apisix/v1_0_0/apisix.k` | `XAPIGateway` | `crossplane_v2/managed_resources/apisix/` | ✅ Complete | Cloud-native API gateway with etcd backend; Helm deployment |
| **Apache Superset** | `framework/templates/superset/v1_0_0/superset.k` | `XSuperset` | `crossplane_v2/managed_resources/superset/` | ✅ Complete | Open-source data visualization & BI platform; Helm deployment |
| **Power BI Connector** | `framework/templates/powerbi/v1_0_0/powerbi_connector.k` | `XPowerBIConnector` | `crossplane_v2/managed_resources/powerbi/` | ✅ Complete | Integration helper for Power BI ↔ QuestDB/Superset connection strings |

### 🚫 Intentionally Unmapped (Stay on Tier-1 GitOps)

| Framework Template | Location | Reason | Alternative |
|---|---|---|---|
| **WebAppModule** | `framework/templates/webapp/` | Application workload; not control-plane | Render as YAML → ArgoCD GitOps |
| **SingleDatabaseModule** | `framework/templates/database/` | Generic; not domain-specific | Render as YAML → ArgoCD GitOps |

### 📋 Completed (All Previously Recommended) ✅

**Status**: All 23 infrastructure services now have complete Crossplane APIs

| Framework Template | Location | Crossplane API | Status | Completed |
|---|---|---|---|---|
| **Logstash** | `framework/templates/elastic/v9_4_1/logstash.k` | `XLogstashInstance` | ✅ Complete | June 4, 2026 (Phase 2b) |
| **Data Prepper** | `framework/templates/dataprepper/v1_0_0/dataprepper.k` | `XDataPrepperPipeline` | ✅ Complete | June 4, 2026 (Phase 2b) |
| **OpenTelemetry** | `framework/templates/opentelemetry/v1_0_0/opentelemetry.k` | `XOpenTelemetryCollector` | ✅ Complete | June 4, 2026 (Phase 2b) |
| **Valkey** | `framework/templates/valkey/v1_0_0/valkey.k` | `XValkeyInstance` | ✅ Complete | June 4, 2026 (Phase 2b) |
| **Fluent Bit** | `framework/templates/fluentbit/v3_2_10/fluentbit.k` | `XFluentBitInstance` | ✅ Complete | June 4, 2026 (Phase 2c) |
| **OpenBao** | `framework/templates/openbao/v1_0_0/openbao.k` | `XOpenBaoInstance` | ✅ Complete | June 4, 2026 (Phase 2c) |

---

## Deployment Philosophy

### For Platform Infrastructure

**Best Practice**: Use Crossplane Managed Resources when available.
```bash
# Good: Intent-level API (Crossplane)
kubectl apply -f - <<EOF
apiVersion: koncept.bluesolution.es/v1alpha1
kind: MongoDBInstance
metadata:
  name: app-db
spec:
  mongodbVersion: "7.0.12"
  members: 3
  storageSize: "50Gi"
EOF
```

### For Application Workloads

**Best Practice**: Use framework template rendering → GitOps.
```bash
# Good: Template-rendered YAML via ArgoCD (Tier 1)
koncept render argocd --factory projects/myapp/pre_releases/factory/
```

**Not Recommended**: Wrapping application Deployments in Crossplane Objects.
```yaml
# Anti-pattern: Don't do this
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
spec:
  manifest:
    apiVersion: apps/v1
    kind: Deployment  # ← Application workloads belong in GitOps, not Crossplane
```

---

## Convergence Strategy (Phase E2)

The generated `kcl_to_crossplane` output path should be updated to:

1. **Detect curated APIs**: When rendering a stack that includes MongoDB, RabbitMQ, etc., check if managed resource exists
2. **Emit managed-resource references**: Instead of wrapping manifests in Object, emit XR/Claim instances
3. **Fall back to bridge**: For services without curated APIs, use provider-kubernetes Object

### Before (Today): All manifests wrapped
```yaml
resources:
  - mongodb-deployment-object
  - mongodb-service-object
  - rabbitmq-deployment-object
```

### After (Phase E2): Mixed curated + bridge
```yaml
resources:
  - mongodb-instance  # ← Curated XR
  - rabbitmq-cluster  # ← Curated XR
  - generic-workload-object  # ← Bridge for unmodeled resources
```

---

## Template Structure Comparison

### Framework Template Example (Raw Approach)
```kcl
# framework/templates/mongodb/v1_0_0/mongodb.k
schema MongoDBCommunityModule(accessory.Accessory):
    kind = "CRD"
    clusterName: str
    mongodbVersion: str
    members?: int = 3
    
    leaders = [...]
    manifest = {
        apiVersion = "mongodbcommunity.mongodb.com/v1"
        kind = "MongoDBCommunity"
        spec = { ... }
    }
```

**Output**: Raw `MongoDBCommunity` manifest (any format: YAML, Helm, Kusion, etc.)

### Crossplane Managed Resource (Intent-First)
```yaml
# crossplane_v2/managed_resources/mongodb/xrd_mongodb.yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
spec:
  schema:
    properties:
      spec:
        properties:
          mongodbVersion: { type: string }
          members: { type: integer, minimum: 1 }
          storageSize: { type: string }
          # ← Describe intent, not implementation
```

**Output**: Platform API abstraction (e.g., `MongoDBInstance`)

---

## Operator Prerequisites

### Framework Template (Render-Time)
Templates assume the operator is already installed on the target cluster.
```bash
# Before rendering:
helm install mongodb mongodb/community-operator -n mongodb

# Then render:
koncept render argocd --factory projects/myapp/pre_releases/factory/
# → Produces MongoDBCommunity manifests ready for deployment
```

### Crossplane Managed Resource (Cluster-Time)
Operators must be pre-installed for reconciliation.
```bash
# Step 1: Install operators (cluster bootstrap, not part of stack)
helmchart repository add mongodb https://mongodb.github.io/helm-charts
helm install mongodb mongodb/community-operator -n mongodb

# Step 2: Create managed resources (via Crossplane clai ms)
kubectl apply -f xr_instance_mongodb.yaml
# ← Crossplane reconciles toward desired state
```

---

## Example: Multi-Service Stack Deployment

### Using Framework Templates (Today)
```bash
cd projects/myapp/pre_releases/
koncept render argocd --factory factory/
# Produces: kubernetes_manifests.yaml + kustomization/ + values.yaml

# GitOps deploy (ArgoCD)
kubectl apply -f output/

# Includes everything: MongoDB, RabbitMQ, app deployments, services, etc.
# All rendered as static YAML manifests
```

### Using Crossplane Managed Resources (Phase E2, Intent-First)
```bash
# Deploy infrastructure via Crossplane
kubectl apply -f - <<EOF
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: MongoDBInstance
metadata:
  name: app-db
spec: { ... }
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: RabbitMQCluster
metadata:
  name: app-events
spec: { ... }
EOF

# Deploy application via GitOps (rendered YAML, no infrastructure)
koncept render argocd --factory projects/myapp/pre_releases/factory/
# → Only emits app Deployments, Services, ConfigMaps (no MongoDB/RabbitMQ manifests)
```

---

## Documentation Locations

| Layer | Documentation |
|-------|---|
| **Framework Templates** | `docs/FRAMEWORK_SCHEMAS.md` | 
| **Framework Builders** | `.github/instructions/framework-builders.instructions.md` |
| **Crossplane Patterns** | `docs/CROSSPLANE_PATTERNS.md` |
| **Crossplane Architecture** | `.github/instructions/crossplane-architecture.instructions.md` |
| **Implementation Status** | `crossplane_v2/IMPLEMENTATION_STATUS.md` (NEW) |
| **Quick Reference** | `crossplane_v2/QUICK_REFERENCE.md` (NEW) |
| **Evolution Plan** | `docs/IDP_EVOLUTION_PLAN.md` §5.7 |

---

## FAQ

### Q: Why isn't `framework/templates/webapp/` mapped to Crossplane?
**A**: Application workloads belong on Tier-1 GitOps. Wrapping Deployments in Crossplane Objects adds complexity without benefit. Keep app deployments in GitOps (ArgoCD) and infrastructure in Crossplane.

### Q: Can I use the same MongoDB template for both YAML rendering AND Crossplane?
**A**: Partially. The KCL template schema (`MongoDBCommunityModule`) generates raw manifests. Crossplane's `XMongoDBInstance` is a separate API. Both can point to the same operator CRD, but they're separate abstractions.

### Q: What if I only want to use Crossplane, not framework templates?
**A**: Valid! Create managed resources directly:
```bash
kubectl apply -f crossplane_v2/managed_resources/mongodb/xr_instance_mongodb.yaml
```
You don't need framework templates if Crossplane covers your infrastructure needs.

### Q: What's the roadmap for the remaining services (Logstash, Data Prepper, OpenTelemetry)?
**A**: See `docs/IDP_EVOLUTION_PLAN.md` Phase 6-7. Create per the established patterns (ECK for Logstash/Kibana, Helm for OpenTelemetry, Deployment for Data Prepper).

### Q: Can I version Crossplane APIs independently from framework templates?
**A**: Yes. Crossplane APIs are v1alpha1; framework templates have their own versioning (v1_0_0, etc.). Decouple them as needed.

---

## Changes From Previous State

**Before June 4, 2026**:
- 4 managed resources: PostgreSQL, Kafka, Keycloak, Cert-Manager

**As of June 4, 2026** (This Implementation):
- **8 new managed resources**: MongoDB, RabbitMQ, Redis, OpenSearch, MinIO, Vault, QuestDB, Elasticsearch
- **1 in-progress**: Kibana (XRD defined, Composition pending)
- **4 recommended for future work**: Logstash, Data Prepper, OpenTelemetry Collector, Valkey

**Total**: 12 complete + 1 partial + 4 planned = 17 platform infrastructure APIs at completion.

---

## Version & Audit Trail

- **Document Version**: 1.0
- **Implementation Date**: June 4, 2026
- **Author Note**: This mapping reflects the state after XRD/Composition creation for core infrastructure services. Kibana, Logstash, and observability stack APIs are recommended for Phase E2 convergence work.


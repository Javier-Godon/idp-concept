# Crossplane Managed Resources — Quick Reference

**Last Updated**: June 4, 2026  
**Implemented Services**: 8 complete + 1 XRD-only

---

## Quick Lookup Table

| Service | Status | XRD | Composition | Instances | Operator | API Type |
|---------|--------|-----|-------------|-----------|----------|----------|
| **MongoDB** | ✅ Complete | ✓ | ✓ | ✓ | Community Operator | `XMongoDBInstance` |
| **RabbitMQ** | ✅ Complete | ✓ | ✓ | ✓ | Cluster Operator | `XRabbitMQCluster` |
| **Redis** | ✅ Complete | ✓ | ✓ | ✓ | OT Operator | `XRedisInstance` (mode-aware) |
| **OpenSearch** | ✅ Complete | ✓ | ✓ | ✓ | K8s Operator | `XOpenSearchCluster` |
| **MinIO** | ✅ Complete | ✓ | ✓ | ✓ | Tenant (archived) | `XMinIOTenant` |
| **Vault** | ✅ Complete | ✓ | ✓ | ✓ | VSO (BUSL-1.1) | `XVaultInstance` |
| **QuestDB** | ✅ Complete | ✓ | ✓ | ✓ | Helm chart | `XQuestDBInstance` |
| **Elasticsearch** | ✅ Complete | ✓ | ✓ | ✓ | ECK | `XElasticsearchCluster` |
| **Kibana** | 🔄 In Progress | ✓ | ⏳ | ⏳ | ECK | `XKibanaInstance` |
| **Logstash** | 📋 Recommended | — | — | — | ECK | — |
| **OpenTelemetry** | 📋 Recommended | — | — | — | Helm + Operator | — |
| **Data Prepper** | 📋 Recommended | — | — | — | Deployment | — |
| **Valkey** | 📋 Recommended | — | — | — | OT Operator | — |

---

## API Access Pattern

All curated API resources are under `koncept.bluesolution.es/v1alpha1`:

```bash
# List available managed resource definitions
kubectl get xrd -l koncept.io/tier=2

# View specific API
kubectl get xpostgresinstances.koncept.bluesolution.es
kubectl get xmongodbinstances.koncept.bluesolution.es
kubectl get xredisinstances.koncept.bluesolution.es
# ... etc

# Create a MongoDB instance (namespace-scoped claim)
kubectl apply -f - <<EOF
apiVersion: koncept.bluesolution.es/v1alpha1
kind: MongoDBInstance
metadata:
  name: app-db
  namespace: app-team
spec:
  namespace: app-team
  mongodbVersion: "7.0.12"
  members: 3
  storageSize: "50Gi"
  environment: production
  owner: app-team
EOF

# Watch composition reconciliation
kubectl get mongodbinstance app-db -n app-team -w

# Check generated resources
kubectl get mongodbcommunity -n app-team
kubectl get objects.kubernetes.crossplane.io -n app-team
```

---

## Composition Patterns

### Pattern A: Provider-Kubernetes Object + Operator CRD
**Used by**: MongoDB, RabbitMQ, Redis, OpenSearch, MinIO, Elasticsearch, Vault (VSO)

```yaml
# Namespace (provider-kubernetes Object)
- kind: Namespace
  implements: v1

# Operator CRD (provider-kubernetes Object)
- kind: MongoDBCommunity / RabbitmqCluster / Redis / OpenSearchCluster / Tenant / Elasticsearch / VaultConnection
  implements: operator CRD
  orchestrated by: function-sequencer (namespace first)
```

**Functions Used**:
- `function-patch-and-transform`: Inject XR fields into manifests
- `function-sequencer`: Enforce namespace → resource ordering
- `function-auto-ready`: Detect readiness from composed resources

### Pattern B: Provider-Helm Release
**Used by**: QuestDB

```yaml
# Namespace (provider-kubernetes Object)
- kind: Namespace
  implements: v1

# Helm Release (provider-helm Release)
- chart: questdb/questdb
  repository: https://questdb.github.io/questdb-helm
  orchestrated by: provider-helm
```

---

## Example Usage

### Standalone MongoDB
```yaml
apiVersion: koncept.bluesolution.es/v1alpha1
kind: MongoDBInstance
metadata:
  name: myapp-db
  namespace: myapp
spec:
  namespace: myapp
  mongodbVersion: "7.0.12"
  members: 1  # Standalone
  storageSize: "10Gi"
  environment: development
  owner: myapp-team
```

### HA MongoDB
```yaml
apiVersion: koncept.bluesolution.es/v1alpha1
kind: MongoDBInstance
metadata:
  name: prod-db
  namespace: prod-data
spec:
  namespace: prod-data
  mongodbVersion: "7.0.12"
  members: 3
  storageSize: "100Gi"
  storageClass: "fast-nvme"
  environment: production
  owner: data-team
```

### Redis Standalone + Cluster
```yaml
# Standalone
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: RedisInstance
metadata:
  name: session-cache
spec:
  namespace: app-cache
  mode: standalone
  nodeCount: 1
  storageSize: "10Gi"

# Cluster
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: RedisInstance
metadata:
  name: distributed-cache
spec:
  namespace: cache-system
  mode: cluster
  nodeCount: 6
  storageSize: "50Gi"
```

### OpenSearch with Dashboards
```yaml
apiVersion: koncept.bluesolution.es/v1alpha1
kind: OpenSearchCluster
metadata:
  name: logs-cluster
  namespace: logging-system
spec:
  namespace: logging-system
  version: "2.13.0"
  nodePoolCount: 3
  diskSize: "100Gi"
  includeDashboards: true
  dashboardReplicas: 2
  enableSecurity: true
  enableMonitoring: true
  environment: production
  owner: logging-team
```

### Vault Secrets Operator
```yaml
apiVersion: koncept.bluesolution.es/v1alpha1
kind: VaultInstance
metadata:
  name: vault-conn
  namespace: vault-system
spec:
  namespace: vault-system
  vaultAddress: "https://vault.prod.internal:8200"
  authMethod: kubernetes
  kubernetesRole: platform-apps
  kubernetesServiceAccount: vault-auth
  environment: production
  owner: vault-team
```

---

## Operator Installation Prerequisites

| Service | Operator | Install Command |
|---------|----------|-----------------|
| MongoDB | MongoDB Community Operator | `helm install mongodb mongodb/community-operator -n mongodb --create-namespace` |
| RabbitMQ | RabbitMQ Cluster Operator | `helm install rabbitmq bitnami/rabbitmq-cluster-operator -n rabbitmq --create-namespace` |
| Redis | OT-CONTAINER-KIT Redis | `helm install redis-operator opstree-charts/redis-operator -n redis-operator --create-namespace` |
| OpenSearch | OpenSearch K8s Operator | (CRDs only or via Helm) |
| MinIO | MinIO Operator | (Archived March 2026; use Helm chart instead) |
| Vault | Vault Secrets Operator | `helm install vault-secrets-operator hashicorp/vault-secrets-operator -n vault --create-namespace` |
| QuestDB | Bitnami Helm | Helm chart; Crossplane provider-helm handles install |
| Elasticsearch | ECK | `helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace` |

---

## Common Operations

### Upgrade Instance Configuration
```bash
# Change MongoDB from 1 to 3 replicas
kubectl patch mongodbinstance myapp-db -n myapp --type=merge -p '{"spec":{"members":3}}'

# Watch reconciliation
kubectl get mongodbcommunity -n myapp -w

# Verify cluster status
kubectl get pod -n myapp -l app=mongodb
```

### Access Credentials
```bash
# Find generated Secret from VSO/connection
kubectl get secrets -n app-team | grep -i mongo

# Or check XR status
kubectl describe mongodbinstance myapp-db -n myapp
```

### Troubleshooting
```bash
# Check composition status
kubectl get composition

# Check XR/claim detailed status
kubectl describe xmongodbinstance <name>
kubectl describe mongodbinstance <name> -n <namespace>

# Check composed resources
kubectl get objects.kubernetes.crossplane.io -n <namespace>

# Check Crossplane logs
kubectl logs -n crossplane-system -f deployment/crossplane
```

---

## Status Fields & Printer Columns

All XRDs include useful printer columns for `kubectl get`:

```
NAME    NAMESPACE          SIZE/MEMBERS    VERSION    STORAGE    READY   AGE
...     app-team           3               7.0.12     50Gi       True    5m
```

View full status:
```bash
kubectl get mongodbinstance -n app-team -o wide
kubectl get xmongodbinstance -o yaml  # Full XR detail
```

---

## References & Next Steps

- **Full Documentation**: See `IMPLEMENTATION_STATUS.md` for complete reference
- **Patterns & Design**: See `docs/CROSSPLANE_PATTERNS.md` §1-§8
- **Evolution Roadmap**: See `docs/IDP_EVOLUTION_PLAN.md` §5.7 (Phase E2 convergence)
- **Acceptance Tests**: `framework/tests/acceptance/cases/crossplane_*.k`
- **Provider Setup**: `crossplane_v2/providers/` and `crossplane_v2/functions/`

---

## Parity Matrix (Updated)

| Infrastructure Service | Crossplane API Status | Framework Template | Notes |
|---|---|---|---|
| PostgreSQL (CNPG) | ✅ `postgres/*` | `postgresql/` | Previously implemented |
| Kafka (Strimzi) | ✅ `kafka_strimzi/*` | `kafka/` | Previously implemented |
| Keycloak | ✅ `keycloak/*` | `keycloak/` | Previously implemented |
| Cert-Manager | ✅ `cert_manager/*` | (cluster infra) | Previously implemented |
| **MongoDB** | ✅ **NEW** `mongodb/*` | `mongodb/` | Community Operator |
| **RabbitMQ** | ✅ **NEW** `rabbitmq/*` | `rabbitmq/` | Cluster Operator |
| **Redis** | ✅ **NEW** `redis/*` | `redis/` | OT Operator, mode-aware |
| **OpenSearch** | ✅ **NEW** `opensearch/*` | `opensearch/` | K8s Operator + Dashboards |
| **MinIO** | ✅ **NEW** `minio/*` | `minio/` | Operator (archived); Helm recommended |
| **Vault** | ✅ **NEW** `vault/*` | `vault/` | VSO (BUSL-1.1) |
| **QuestDB** | ✅ **NEW** `questdb/*` | `questdb/` | Helm chart, no native operator |
| **Elasticsearch** | ✅ **NEW** `elastic/elasticsearch/*` | `elastic/` | ECK operator |
| **Kibana** | 🔄 **In Progress** `elastic/kibana/*` | `elastic/` | ECK, XRD created |
| Logstash | 📋 Recommended | `elastic/` | ECK; create per Kibana pattern |
| OpenTelemetry | 📋 Recommended | `opentelemetry/` | Helm operator + CRD |
| Data Prepper | 📋 Recommended | `observability/dataprepper/` | Deployment-native |
| Valkey | 📋 Optional | `valkey/` | Redis-compatible; OT Operator |
| Application Workloads (webapp, generic DB) | 🚫 Excluded | `webapp/`, `database/` | Stay on Tier-1 GitOps/YAML |

---

## License & Attribution

- **MongoDB Community**: Apache-2.0
- **RabbitMQ Cluster Operator**: MPL-2.0
- **OT Redis Operator**: Apache-2.0
- **OpenSearch**: Apache-2.0 (project); operator Apache-2.0
- **MinIO Operator**: AGPL-3.0 (archived); Bitnami Helm chart Apache-2.0
- **Vault Secrets Operator**: BUSL-1.1 (not fully open-source)
- **QuestDB**: Apache-2.0
- **Elasticsearch**: Elastic license v2 (not fully open-source)
- **ECK**: Elastic license v2 (not fully open-source)

See `docs/SECURITY.md` for implications and alternatives.


# Apache APISIX, Superset & Power BI Integration Guide

**Date**: June 7, 2026  
**Version**: 1.0  
**Summary**: Complete deployment guide for Apache APISIX API Gateway, Apache Superset Analytics Platform, and Power BI integration with QuestDB data platform.

## Overview

This guide demonstrates how to deploy and integrate three complementary platforms:

1. **Apache APISIX** — Cloud-native API Gateway for managing, routing, and securing APIs
2. **Apache Superset** — Open-source data visualization and Business Intelligence platform
3. **Power BI Connector** — Kubernetes-native integration helper for connecting Power BI to data sources

Together, these support:

- **API Management**: APISIX routes requests to backend services
- **Data Exploration**: Superset provides collaborative data visualization and SQL exploration
- **Enterprise BI**: Power BI connects to QuestDB and Superset for dashboard creation and reporting
- **Multi-Environment Support**: All templates support local/development/staging/production sizing

---

## Architecture Overview

```
┌─────────────────┐
│   Power BI      │  (External — not K8s)
│   Desktop/Cloud │
└────────┬────────┘
         │ ODBC / PostgreSQL Wire Protocol
         │
    ┌────▼────────────────────────────────────────┐
    │  Kubernetes Cluster                          │
    │                                              │
    │  ┌──────────────────────────────────────┐  │
    │  │  Apache APISIX (Gateway)              │  │
    │  │  - Request routing                    │  │
    │  │  - Rate limiting & auth               │  │
    │  │  - Plugins: OAuth2, JWT, etc.        │  │
    │  │  (Port 80/443 → Services)            │  │
    │  └──────────────────────────────────────┘  │
    │                      │                      │
    │       ┌──────────────┼──────────────┐      │
    │       │              │              │      │
    │  ┌────▼────┐  ┌──────▼──────┐  ┌───▼──┐  │
    │  │ Superset│  │  QuestDB    │  │ Apps │  │
    │  │ Web UI  │  │  (TS DB)    │  │      │  │
    │  └────┬────┘  └──────┬──────┘  └──────┘  │
    │       │              │                    │
    │  ┌────▼──────────────▼──────┐            │
    │  │ PostgreSQL Backend        │            │
    │  │ (Superset state storage)  │            │
    │  └──────────────────────────┘            │
    │                                           │
    │  ┌──────────────────────────────────────┐ │
    │  │ Power BI Connector ConfigMap          │ │
    │  │ (Connection strings & documentation) │ │
    │  └──────────────────────────────────────┘ │
    │                                            │
    └────────────────────────────────────────────┘
```

---

## Deployment Scenarios

### Scenario 1: Production Full Stack (Recommended)

Deploy all three with production-grade HA and persistence.

**Step 1: Deploy Infrastructure**

```bash
# Create namespaces and storage setup
kubectl create namespace gateway-prod
kubectl create namespace analytics-prod
kubectl create namespace infra-prod

# Optional: Set up storage classes (Ceph/Longhorn)
# kubectl apply -f your-storage-setup.yaml
```

**Step 2: Deploy via Framework Templates (KCL)**

```kcl
import templates.apisix.v1_0_0.apisix as apisix
import templates.superset.v1_0_0.superset as superset
import templates.powerbi.v1_0_0.powerbi_connector as pbi

# APISIX Gateway
_gateway = apisix.APIGatewayModule {
    name = "prod-gateway"
    namespace = "gateway-prod"
    footprint = "production"
    adminPort = 9180
    gatewayHttpPort = 80
    gatewayHttpsPort = 443
    dashboardPort = 3000
}.instance

# Superset with PostgreSQL backend connection
_superset = superset.SupersetModule {
    name = "prod-superset"
    namespace = "analytics-prod"
    footprint = "production"
    databaseUri = "postgresql://superset:secretpassword@postgres.infra-prod.svc.cluster.local:5432/superset"
    redisUri = "redis://redis.infra-prod.svc.cluster.local:6379/1"
    webReplicas = 3
    workerReplicas = 2
    persistenceSize = "50Gi"
}.instance

# Power BI Connector
_pbi_connector = pbi.PowerBIConnectorModule {
    name = "prod-analytics-connector"
    namespace = "analytics-prod"
    questdbHost = "questdb.infra-prod.svc.cluster.local"
    questdbPort = 5432
    supersetHost = "superset.analytics-prod.svc.cluster.local"
    postgresHost = "postgres.infra-prod.svc.cluster.local"
    footprint = "production"
}.instance
```

**Step 3: Deploy via Crossplane (Intent-Level API)**

```bash
# Deploy via Crossplane managed resources
kubectl apply -f - <<EOF
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: APIGateway
metadata:
  name: prod-gateway
spec:
  namespace: gateway-prod
  environment: production
  adminPort: 9180
  gatewayHttpPort: 80
  gatewayHttpsPort: 443
  gatewayType: LoadBalancer
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: Superset
metadata:
  name: prod-superset
spec:
  namespace: analytics-prod
  environment: production
  databaseUri: "postgresql://superset:secretpassword@postgres.infra-prod.svc.cluster.local:5432/superset"
  redisUri: "redis://redis.infra-prod.svc.cluster.local:6379/1"
  webReplicas: 3
  workerReplicas: 2
  persistenceSize: "50Gi"
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: PowerBIConnector
metadata:
  name: prod-analytics-connector
spec:
  namespace: analytics-prod
  dataSources:
    - questdb
    - superset
    - postgres
  questdbHost: questdb.infra-prod.svc.cluster.local
  supersetHost: superset.analytics-prod.svc.cluster.local
  postgresHost: postgres.infra-prod.svc.cluster.local
  environment: production
EOF
```

**Step 4: Configure APISIX Routes**

```bash
# Port-forward to APISIX Admin API (if not exposed)
kubectl port-forward -n gateway-prod svc/prod-gateway 9180:9180 &

# Create upstream service (Superset)
curl http://localhost:9180/apisix/admin/v1/upstreams/superset-upstream \
  -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "nodes": [{
      "host": "superset.analytics-prod.svc.cluster.local",
      "port": 8088,
      "weight": 1
    }],
    "timeout": 60,
    "retries": 2,
    "retry_timeout": 5,
    "desc": "Superset Analytics Backend"
  }'

# Create route (/analytics → Superset)
curl http://localhost:9180/apisix/admin/v1/routes/analytics-route \
  -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/analytics/*",
    "upstream_id": "superset-upstream",
    "enable_websocket": true,
    "timeout": {
      "connect": 60,
      "send": 60,
      "read": 60
    }
  }'
```

---

### Scenario 2: Development Stack (Single Replicas)

Lightweight deployment for development/testing with local storage.

```bash
kubectl apply -f - <<EOF
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: APIGateway
metadata:
  name: dev-gateway
spec:
  namespace: gateway-dev
  environment: development
  gatewayType: NodePort
  etcdReplicas: 1
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: Superset
metadata:
  name: dev-superset
spec:
  namespace: analytics-dev
  environment: development
  databaseUri: "postgresql://superset:devpass@postgres-dev.svc.cluster.local:5432/superset"
  webReplicas: 1
  workerReplicas: 1
  persistenceSize: "10Gi"
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: PowerBIConnector
metadata:
  name: dev-analytics-connector
spec:
  namespace: analytics-dev
  dataSources:
    - questdb
  questdbHost: questdb-dev.svc.cluster.local
  environment: development
EOF
```

---

### Scenario 3: Local/Kind Deployment

Minimal setup for laptop/kind cluster.

```bash
kubectl apply -f - <<EOF
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: APIGateway
metadata:
  name: local-gateway
spec:
  namespace: gateway
  environment: local
  gatewayType: NodePort
  etcdReplicas: 1
  etcdStorageSize: "1Gi"
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: Superset
metadata:
  name: local-superset
spec:
  namespace: analytics
  environment: local
  databaseUri: "postgresql://superset:localpass@postgres.default.svc.cluster.local:5432/superset"
  webReplicas: 1
  persistenceEnabled: false
  serviceType: ClusterIP
---
apiVersion: koncept.bluesolution.es/v1alpha1
kind: PowerBIConnector
metadata:
  name: local-analytics-connector
spec:
  namespace: analytics
  dataSources:
    - questdb
  questdbHost: questdb.default.svc.cluster.local
  environment: local
EOF
```

---

## Power BI Configuration

### Prerequisites

- Power BI Desktop (Windows) or Power BI Cloud account
- Network access to Kubernetes cluster (VPN/Direct/Port-forward)
- Credentials for QuestDB and PostgreSQL

### Step 1: Port Forward or Expose Services

```bash
# Option A: Port-forward (for local testing)
kubectl port-forward -n analytics-prod svc/superset 8088:8088 &
kubectl port-forward -n infra-prod svc/questdb 5432:5432 &
kubectl port-forward -n infra-prod svc/postgres 5432:5433 &  # Use different local port

# Option B: Expose via APISIX routes (for production)
# (See "Configure APISIX Routes" section above)
```

### Step 2: Get Connection Details

```bash
# Retrieve connector configuration from ConfigMap
kubectl get configmap -n analytics-prod powerbi-questdb-connector -o yaml
kubectl get configmap -n analytics-prod powerbi-postgres-connector -o yaml
```

### Step 3: Power BI Desktop Connection

**QuestDB Connection (PostgreSQL Wire Protocol)**:

1. Open Power BI Desktop
2. Get Data → Postgres
3. Fill in:
   - **Server**: `localhost` (or Kubernetes node IP)
   - **Database**: `qdb`
   - **Username**: `admin`
   - **Password**: (provide from K8s Secret)
4. Connection Mode: **DirectQuery** (recommended for real-time)
5. Click OK

**Superset Integration** (optional — export data from Superset):

1. In Superset UI: Create dashboard and charts
2. Export dataset to CSV/Parquet
3. In Power BI: Get Data → File → CSV
4. Load and refresh as needed

---

## Security Considerations

### APISIX Security

1. **Enable Plugins**:

   ```bash
   # Enable OAuth2 plugin for API protection
   curl http://localhost:9180/apisix/admin/v1/plugins/oauth2 \
     -X PATCH \
     -H "Content-Type: application/json" \
     -d '{"SCHEME_URI":"/oauth/authorize"}'
   ```

2. **HTTPS/TLS**:
   - Route traffic through Cert-Manager for automatic certificate management
   - Configure TLS in APISIX dashboard or via API

### Superset Security

1. **Use Secrets for Database Credentials**:

   ```bash
   kubectl create secret generic superset-db-secret \
     -n analytics-prod \
     --from-literal=uri="postgresql://superset:PASSWORD@postgres.svc:5432/superset"
   ```

2. **RBAC in Superset**:
   - Create databases and datasets with row-level security
   - Limit user access per team

### Power BI Security

1. **Never Hardcode Credentials**:
   - Use Kubernetes Secrets for database passwords
   - Rotate credentials regularly

2. **Network Policies**:

   ```bash
   # Restrict traffic to analytics namespace
   kubectl apply -f - <<EOF
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: analytics-network-policy
     namespace: analytics-prod
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
     - Egress
     ingress:
     - from:
       - namespaceSelector:
           matchLabels:
             name: gateway-prod
   EOF
   ```

---

## Monitoring & Troubleshooting

### Check Deployment Status

```bash
# APISIX
kubectl get deployment -n gateway-prod
kubectl logs -n gateway-prod -l app=apisix -f

# Superset
kubectl get deployment,statefulset -n analytics-prod
kubectl logs -n analytics-prod -l app=superset -f

# Power BI Connector
kubectl get configmap -n analytics-prod
```

### Test Connectivity

```bash
# Test APISIX Admin API
kubectl exec -it -n gateway-prod $(kubectl get pod -n gateway-prod -l app=apisix -o jsonpath='{.items[0].metadata.name}') -- \
  curl -s http://localhost:9180/apisix/admin/v1/status

# Test Superset
kubectl port-forward -n analytics-prod svc/superset 8088:8088
# Open http://localhost:8088 in browser

# Test QuestDB connection from Superset
kubectl exec -it -n analytics-prod $(kubectl get pod -n analytics-prod -l app=superset -o jsonpath='{.items[0].metadata.name}') -- \
  psql -h questdb.infra-prod.svc.cluster.local -U admin -d qdb -c "SELECT * FROM tables() LIMIT 1;"
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| APISIX admin unreachable | Service not running | `kubectl describe svc -n gateway-prod` |
| Superset can't reach DB | PostgreSQL not ready | Wait for PostgreSQL Helm chart to complete |
| Power BI can't connect to QuestDB | Network policy blocking | Create NetworkPolicy with proper egress rules |
| Slow Superset queries | Missing indexes in QuestDB | Create appropriate indexes on QuestDB tables |

---

## Footprint Configuration Reference

### APISIX Footprints

| Footprint | Etcd Replicas | Gateway Type | CPU/Memory | Use Case |
|-----------|---------------|--------------|-----------| ---------|
| local | 1 | NodePort | 25m/64Mi - 250m/256Mi | Laptop/kind |
| development | 1 | NodePort | 50m/128Mi - 500m/512Mi | Shared dev cluster |
| staging | 2 | LoadBalancer | 100m/128Mi - 500m/512Mi | Staging environment |
| production | 3 | LoadBalancer | 100m/128Mi - 500m/512Mi | Production HA |

### Superset Footprints

| Footprint | Web Replicas | Worker Replicas | Storage | Use Case |
|-----------|--------------|-----------------|---------|----------|
| local | 1 | 1 | None | Laptop/kind |
| development | 1 | 1 | 10Gi | Shared dev cluster |
| staging | 2 | 1 | 20Gi | Staging environment |
| production | 3 | 2 | 50Gi | Production HA |

---

## Upgrade & Maintenance

### Updating Chart Versions

```bash
# Update APISIX chart
kubectl set env -n gateway-prod deployment/prod-gateway CHART_VERSION=2.5.0

# Update Superset
kubectl patch xsuperset prod-superset -n analytics-prod --type merge \
  -p '{"spec":{"chartVersion":"0.15.0"}}'
```

### Backup & Restore

```bash
# Backup Superset database
kubectl exec -n infra-prod postgres-pod -- \
  pg_dump -U superset superset > /tmp/superset_backup.sql

# Restore
kubectl exec -i -n infra-prod postgres-pod -- \
  psql -U superset superset < /tmp/superset_backup.sql
```

---

## Reference Documentation

- **APISIX**: https://apisix.apache.org/docs/
- **Superset**: https://superset.apache.org/docs/introduction/overview
- **QuestDB**: https://questdb.io/docs/integrations/overview
- **Power BI QuestDB Connector**: https://questdb.io/docs/integrations/powerbi
- **Framework Templates**: See `.github/instructions/framework-builders.instructions.md`
- **Crossplane Managed Resources**: See `crossplane_v2/TEMPLATE_MAPPING.md`

---

## Version & Support

- **Document Version**: 1.0
- **Framework Version**: v0.10.0
- **APISIX Chart**: 2.4.0
- **Superset Chart**: 0.14.1
- **Created**: June 7, 2026

For issues or updates, refer to official project documentation or community channels.

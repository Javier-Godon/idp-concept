# Acceptance Testing Implementation Guide

**Date**: 2026-06-08  
**Version**: 1.0  
**Purpose**: Instructions for running acceptance tests for APISIX, Superset, and Power BI templates

---

## Quick Start

### Run All New Tests

```bash
cd /home/javier/javier/workspaces/public_github/idp-concept

# Rendering verification (compilation only)
bash scripts/verify.sh

# Kind cluster integration tests
./scripts/acceptance_kind.sh --case apisix
./scripts/acceptance_kind.sh --case superset  
./scripts/acceptance_kind.sh --case powerbi
./scripts/acceptance_kind.sh --case apisix-superset-questdb-stack
./scripts/acceptance_kind.sh --case powerbi-questdb-superset-stack
```

### Run All Tests Together

```bash
# Run platform group (includes apisix, superset, powerbi)
./scripts/acceptance_kind.sh --case platform

# Run integration group (includes new stack tests)
./scripts/acceptance_kind.sh --case integrations

# Run everything
./scripts/acceptance_kind.sh --case all
```

---

## Individual Test Details

### 1. APISIX Workload Test

**File**: `framework/tests/acceptance/cases/apisix_workload.k`

**What it tests**:

- Apache APISIX Helm chart rendering
- etcd backend configuration
- Port and replica settings
- Dashboard and admin API configuration

**Run it**:

```bash
./scripts/acceptance_kind.sh --case apisix
```

**Expected output**:

```
✓ Renders Helm Release for APISIX
✓ Creates namespace idp-acceptance-apisix
✓ Configures 1 etcd replica with 1Gi storage
✓ Sets admin port to 9180
✓ Sets gateway HTTP/HTTPS to 80/443
✓ Enables dashboard on port 3000
```

### 2. Superset Workload Test

**File**: `framework/tests/acceptance/cases/superset_workload.k`

**What it tests**:

- Superset Helm chart rendering
- Database backend connection (PostgreSQL)
- Redis cache and Celery broker
- Web and worker replica configuration
- Persistence configuration

**Run it**:

```bash
./scripts/acceptance_kind.sh --case superset
```

**Expected output**:

```
✓ Renders Helm Release for Superset
✓ Creates namespace idp-acceptance-superset
✓ Configures PostgreSQL connection
✓ Configures Redis cache
✓ Sets 1 web replica + 1 worker replica
✓ Allocates 5Gi persistent storage
```

### 3. Power BI Connector Test

**File**: `framework/tests/acceptance/cases/powerbi_workload.k`

**What it tests**:

- Power BI connector ConfigMap generation
- Connection string documentation
- QuestDB PostgreSQL wire protocol setup
- Superset integration details
- PostgreSQL connection settings

**Run it**:

```bash
./scripts/acceptance_kind.sh --case powerbi
```

**Expected output**:

```
✓ Renders ConfigMap for Power BI Connector
✓ Creates namespace idp-acceptance-powerbi
✓ Generates QuestDB connection string
✓ Documents Superset integration
✓ Generates PostgreSQL connection URI
✓ Includes ODBC and authentication details
```

### 4. APISIX + Superset + QuestDB Stack Test

**File**: `framework/tests/acceptance/cases/apisix_superset_questdb_stack_workload.k`

**What it tests**:

- Multi-module deployment in shared namespace
- Service interdependencies
- Network connectivity between services
- QuestDB time-series database
- APISIX gateway routing setup

**Run it**:

```bash
./scripts/acceptance_kind.sh --case apisix-superset-questdb-stack
```

**Expected output**:

```
✓ Creates shared namespace idp-acceptance-analytics-stack
✓ Deploys APISIX gateway with etcd backend
✓ Deploys QuestDB with 1Gi storage
✓ Deploys Superset with PostgreSQL backend
✓ All services discoverable via DNS
✓ Dependency ordering maintained
```

### 5. Power BI + QuestDB + Superset + PostgreSQL Stack Test

**File**: `framework/tests/acceptance/cases/powerbi_questdb_superset_stack_workload.k`

**What it tests**:

- Full analytics backend integration
- Multi-datasource configuration
- Power BI connector with all backends
- Cross-module networking
- Complete deployment scenario

**Run it**:

```bash
./scripts/acceptance_kind.sh --case powerbi-questdb-superset-stack
```

**Expected output**:

```
✓ Creates shared namespace idp-acceptance-powerbi-full
✓ Deploys QuestDB database
✓ Deploys Superset analytics platform
✓ Generates Power BI connector ConfigMaps
✓ Provides connection strings for all datasources
✓ All manifests render without errors
```

---

## Test Categories

### PLATFORM_CASES (Platform Infrastructure Services)

```bash
./scripts/acceptance_kind.sh --case platform
```

Now includes:

- `apisix`
- `superset`
- `powerbi`
- (plus existing platform cases)

### INTEGRATION_CASES (Multi-Module Scenarios)

```bash
./scripts/acceptance_kind.sh --case integrations
```

Now includes:

- `apisix-superset-questdb-stack`
- `powerbi-questdb-superset-stack`
- (plus existing integration cases)

### TEMPLATE_CASES (All Template Module Tests)

```bash
./scripts/acceptance_kind.sh --case templates
```

Now includes all 39+ template test cases including:

- `apisix`, `superset`, `powerbi`
- (plus existing template cases)

---

## Verification Commands

### Quick Render Check (No cluster required)

```bash
cd framework

# Check individual fixtures compile
kcl run tests/acceptance/cases/apisix_workload.k > /tmp/apisix.yaml
kcl run tests/acceptance/cases/superset_workload.k > /tmp/superset.yaml  
kcl run tests/acceptance/cases/powerbi_workload.k > /tmp/powerbi.yaml

# Check stacks compile
kcl run tests/acceptance/cases/apisix_superset_questdb_stack_workload.k > /tmp/stack1.yaml
kcl run tests/acceptance/cases/powerbi_questdb_superset_stack_workload.k > /tmp/stack2.yaml

# Verify YAML is valid
for f in /tmp/{apisix,superset,powerbi,stack1,stack2}.yaml; do
  echo "Checking $f:"
  grep -c "apiVersion" "$f"
  grep -c "kind" "$f"
done
```

### Full Verification Suite

```bash
# Run all linting and rendering tests
bash scripts/verify.sh
```

This will:

1. Lint all KCL source files
2. Render all acceptance fixtures (including new ones)
3. Run all KCL tests
4. Test all render output formats for erp_back factory

---

## Expected Test Outputs

### Rendered APISIX Manifest

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: acceptance-apisix
  namespace: idp-acceptance-apisix
spec:
  chart:
    name: apisix
    repository: https://charts.apiseven.com
    version: "2.4.0"
  values:
    apisix:
      replicas: 1
    etcd:
      replicaCount: 1
      persistence:
        enabled: true
        size: 1Gi
    admin:
      enabled: true
      port: 9180
    gateway:
      type: NodePort
      http:
        port: 80
      https:
        port: 443
    dashboard:
      enabled: true
      port: 3000
```

### Rendered Superset Manifest

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: acceptance-superset
  namespace: idp-acceptance-superset
spec:
  chart:
    name: superset
    repository: https://apache.github.io/superset
    version: "0.14.1"
  values:
    supersetDatabaseUri: postgresql://superset:test@postgres-dev.default:5432/superset
    supersetNode:
      replicaCount: 1
    supersetWorker:
      replicaCount: 1
    persistence:
      enabled: true
      size: 5Gi
    service:
      type: NodePort
      port: 8088
```

### Rendered Power BI Connector Manifests

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: acceptance-pbi-connector
  namespace: idp-acceptance-powerbi
data:
  connector-info.md: |
    # Power BI QuestDB Connector Configuration
    
    ## QuestDB Connection (PostgreSQL wire protocol)
    **Host:** questdb.default.svc.cluster.local
    **Port:** 5432
    ...
  questdb-connection.txt: |
    Driver=PostgreSQL Unicode;Server=questdb.default.svc.cluster.local;Port=5432;...
```

---

## Troubleshooting

### Issue: "cannot find module" errors

**Solution**: Ensure framework dependencies are resolved:

```bash
cd framework
kcl mod download
kcl run tests/acceptance/cases/apisix_workload.k
```

### Issue: "Connection refused" when running tests on kind

**Solution**: Prerequisites must be running:

```bash
# For Superset tests, PostgreSQL and Redis must be available
# Install them first or mock them:

kubectl create deployment postgres-dev \
  --image=postgres:15 \
  --env="POSTGRES_PASSWORD=password"

kubectl create deployment redis-dev \
  --image=redis:7
```

### Issue: Helm chart not found

**Solution**: Add Helm repositories:

```bash
helm repo add apisix https://charts.apiseven.com
helm repo add superset https://apache.github.io/superset
helm repo update
```

### Issue: Tests fail at rendering stage

**Solution**: Check KCL version and dependencies:

```bash
kcl version
kcl mod tidy
kcl lint framework/templates/apisix/v1_0_0/apisix.k
```

---

## Test Coverage Summary

| Test | Type | Focus | Status |
|------|------|-------|--------|
| apisix_workload.k | L0 Render | Helm chart rendering | ✅ PASS |
| superset_workload.k | L0 Render | Helm chart rendering | ✅ PASS |
| powerbi_workload.k | L0 Render | ConfigMap rendering | ✅ PASS |
| apisix_superset_questdb_stack_workload.k | L1 Integration | Multi-module stack | ✅ PASS |
| powerbi_questdb_superset_stack_workload.k | L1 Integration | Full analytics backend | ✅ PASS |

---

## Integration Testing Checklist

Before deploying to production, verify:

- [ ] All individual fixtures render without errors
- [ ] All stack fixtures render without errors
- [ ] Kind cluster successfully applies all manifests (dry-run)
- [ ] Services are discoverable via DNS names
- [ ] Configuration values are correctly injected
- [ ] Resource limits are applied per environment
- [ ] Persistence volumes are properly configured
- [ ] Service types match environment expectations
- [ ] All Helm repositories are configured
- [ ] Database backends are accessible
- [ ] Network policies don't block inter-service communication

---

## Next Test Phases

### L2: Live Deployment Testing

Run actual kubectl apply on kind cluster:

```bash
# Create kind cluster
kind create cluster --name acceptance

# Apply APISIX
kubectl apply -f /tmp/apisix.yaml

# Apply Superset with dependencies
kubectl apply -f /tmp/postgres-dev.yaml
kubectl apply -f /tmp/redis-dev.yaml
kubectl apply -f /tmp/superset.yaml

# Verify pods roll out
kubectl rollout status deployment -n idp-acceptance-superset
```

### L3: Runtime Validation

Test actual service functionality:

```bash
# Port-forward to APISIX admin
kubectl port-forward -n idp-acceptance-apisix svc/acceptance-apisix 9180:9180 &

# Test admin API
curl http://localhost:9180/apisix/admin/v1/status

# Port-forward to Superset
kubectl port-forward -n idp-acceptance-superset svc/acceptance-superset 8088:8088 &

# Test web UI
curl http://localhost:8088/health
```

### L4: Integration Testing

Test the full stack together:

```bash
# Deploy all manifests from stack integration tests
kubectl apply -f /tmp/stack1.yaml
kubectl apply -f /tmp/stack2.yaml

# Verify service discovery
kubectl exec -it <superset-pod> -- \
  psql -h full-questdb.default.svc.cluster.local -d qdb -c "SELECT count(*) FROM tables()"

# Verify APISIX routes
curl -X GET http://localhost:80/analytics/
```

---

## Documentation References

- **Framework Templates**: `.github/instructions/framework-builders.instructions.md`
- **Acceptance Testing**: `.github/instructions/acceptance-testing.instructions.md`
- **Integration Guide**: `docs/APISIX_SUPERSET_POWERBI_INTEGRATION.md`
- **Crossplane Architecture**: `.github/instructions/crossplane-architecture.instructions.md`
- **Test Report**: `docs/ACCEPTANCE_TEST_REPORT_NEW_TEMPLATES.md`

---

## Support

For issues or questions:

1. Check test fixtures in `framework/tests/acceptance/cases/`
2. Review acceptance testing instructions
3. Run individual fixtures with verbose KCL output:

   ```bash
   kcl run -v tests/acceptance/cases/apisix_workload.k
   ```

4. Check Helm chart defaults and values
5. Verify all dependencies are installed

---

*Last Updated: 2026-06-08*

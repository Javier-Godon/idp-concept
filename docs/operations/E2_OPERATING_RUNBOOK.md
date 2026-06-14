# E2.3 Operating Runbook — Crossplane V2 Infrastructure Management

**Document Version**: 1.0  
**Date**: June 7, 2026  
**Target Audience**: Platform engineers, infrastructure teams, SREs  
**Scope**: Day-2 operations for Crossplane V2 managed resources (Track 1)

---

## Quick Start (5 minutes)

### Install Crossplane Cluster Prerequisites

```bash
# 1. Install Crossplane (assumes k8s cluster available)
helm repo add crossplane-stable https://charts.crossplane.io
helm install crossplane \
  crossplane-stable/crossplane \
  --create-namespace \
  --namespace crossplane-system

# 2. Install platforms and functions (from generated output)
kubectl apply -f output/crossplane/prerequisites/providers.yaml
kubectl apply -f output/crossplane/prerequisites/functions.yaml

# Wait for providers to be ready
kubectl wait --for=condition=Installed \
  providers --all \
  -n crossplane-system \
  --timeout=300s
```

### Deploy Platform APIs

```bash
# 1. Install the composite resource definition
kubectl apply -f output/crossplane/xrd.yaml

# 2. Install the composition (pipeline)
kubectl apply -f output/crossplane/composition.yaml

# 3. Verify APIs are registered
kubectl api-resources | grep koncept.bluesolution.es
```

### Provision Infrastructure (Track 1)

```bash
# Apply the curated Claims for infrastructure services
kubectl apply -f output/crossplane/managed_resources/

# Watch for reconciliation
kubectl get claims --watch -n default
```

### Trigger Application Workload (Track 2)

```bash
# Apply the composite resource (triggers Track 2 bridge resources)
kubectl apply -f output/crossplane/xr.yaml

# Monitor completion
kubectl describe xr <stack-name>-xr
```

---

## Day-2 Operations

### 1. Inspect Claim Status

#### Check Ready Status

```bash
# List all Claims in a namespace
kubectl get claims -n <namespace>

# Watch a specific Claim
kubectl get monitordb <name> -n <namespace> --watch

# Describe full status
kubectl describe mongodbinstance <name> -n <namespace>
```

**Output Interpretation**:

```
NAME                    READY   SYNCED   AGE
my-database-claim       True    True     5m

# READY: Underlying infrastructure is operational; spec applied successfully
# SYNCED: Claim status has been updated from composition results
```

#### Diagnose Failures

```bash
# 1. Check Claim conditions
kubectl describe mongodbinstance <name> -n <namespace>

# Look for Status.Conditions section:
# - Ready: True/False (infrastructure operational)
# - Synced: True/False (claim status synchronized)
# - Error messages in .status.conditions[*].message

# 2. Check Composition pipeline status
kubectl describe xr <stack-name>-xr | grep -A 20 "Pipeline"

# 3. Check provider logs
kubectl logs -n crossplane-system deployment/crossplane-provider-kubernetes

# 4. Check function execution logs
kubectl logs -n crossplane-system function-patch-and-transform-<hash>
```

### 2. Connection Details & Discovery

#### Retrieve Connection Secrets

```bash
# Each Claim can expose connection details as Kubernetes Secrets
# These are readable by application workloads that need to connect

# Example: PostgreSQL connection secret
kubectl get secret <postgres-claim-name>-conn -o jsonpath='{.data.endpoint}' | base64 -d
# Outputs: postgres-cluster.postgresql.svc.cluster.local:5432

# All connection fields available:
kubectl get secret <postgres-claim-name>-conn -o yaml
```

**Common Connection Secret Keys** (by service):

| Service | Keys | Usage |
|---------|------|-------|
| PostgreSQL | `endpoint`, `port`, `username`, `password`, `database` | JDBC, psql, libraries |
| MongoDB | `endpoint`, `port`, `username`, `password`, `database` | mongosh, drivers |
| Kafka | `bootstrap-servers`, `sasl-mechanism`, `username`, `password` | Kafka clients |
| Redis | `endpoint`, `port`, `password` | redis-cli, lettuce |

#### Reference Secrets in Workload Pods

```yaml
# Example Deployment that uses PostgreSQL connection
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: my-postgres-claim-conn
              key: endpoint
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-postgres-claim-conn
              key: password
```

### 3. Update a Claim

#### Modify Claim Spec

```bash
# Edit a Claim inline
kubectl edit mongodbinstance <name> -n <namespace>

# Or patch a specific field
kubectl patch mongodbinstance <name> \
  -n <namespace> \
  -p '{"spec":{"replicas":3}}' \
  --type=merge
```

#### Monitor Update Progress

```bash
# Watch the Claim status while updating
kubectl get mongodbinstance <name> -n <namespace> --watch

# Check Composition pipeline execution
kubectl describe xr <stack-name>-xr | tail -20
```

**What happens during an update**:

1. Claim spec is modified
2. Composition pipeline re-runs with new spec
3. Provider applies changes (e.g., Helm Release updated, CNPG Cluster scaled)
4. Status.Conditions updated as resources reconcile
5. `.status.phase` becomes "Ready" when all resources are operational

### 4. Delete a Claim (Safe Removal)

#### Check Dependencies

```bash
# Before deleting, verify nothing depends on this claim
kubectl get pods --all-namespaces \
  -o yaml | grep -i <claim-name>

# Check if any Secrets are mounted in running pods
kubectl describe secret <claim-name>-conn --all-namespaces
```

#### Delete with Protection

```bash
# Crossplane uses finalizers to prevent accidental deletion
# Standard delete will keep the underlying resource

kubectl delete mongodbinstance <name> -n <namespace>

# Claim is removed, but MongoDB cluster remains (safe)
# To enable deletion of underlying resources, set finalizer policy:

kubectl patch claim <name> \
  -p '{"spec":{"deletionPolicy":"Delete"}}' \
  --type=merge

# Now delete will also remove the underlying MongoDB cluster
kubectl delete mongodbinstance <name> -n <namespace>
```

**Deletion Policies**:

- `Orphan` (default): Keep underlying resource after Claim deletion
- `Delete`: Remove underlying resource when Claim is deleted

---

## Monitoring & Observability

### 1. Cluster-Level Monitoring

#### Prometheus Metrics

```bash
# Install Prometheus operator (if not already present)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Expose metrics from Crossplane providers
# Providers emit metrics on port 8080 by default
kubectl port-forward -n crossplane-system svc/crossplane 8080 &
curl http://localhost:8080/metrics | grep crossplane
```

**Key Metrics**:

```
crossplane_managed_resources_list_duration_seconds
crossplane_managed_resources_reconcile_duration_seconds
crossplane_managed_resources_reconcile_error_total
```

#### Grafana Dashboards

Import community dashboards:

- **Crossplane**: https://grafana.com/grafana/dashboards/17373

### 2. Claim-Level Observability

#### Status Conditions (Built-In)

```bash
# Every Claim has .status.conditions with timestamps and messages
kubectl describe mongodbinstance <name> -n <namespace>

# Status fields include:
# - .status.phase: Creating | Active | Deleting
# - .status.conditions[*].type: Ready, Synced, ...
# - .status.conditions[*].status: True | False | Unknown
# - .status.conditions[*].lastTransitionTime: When status changed
# - .status.conditions[*].message: Human-readable info/errors
```

#### Custom Alerts

```yaml
# Example: Alert if PostgreSQL Claim is not Ready for 10 minutes
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: crossplane-claim-alerts
spec:
  groups:
  - name: claims
    interval: 30s
    rules:
    - alert: PostgresClaimNotReady
      expr: |
        crossplane_claim_synced{claim_kind="PostgresInstance"} == 0
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "PostgreSQL Claim not Ready"
```

### 3. Audit & Compliance

#### Event Logging

```bash
# Crossplane records all Claim changes as Kubernetes Events
kubectl get events -n <namespace> --field-selector involvedObject.name=<claim-name>

# Events include:
# - Created, Modified, Deleted timestamps
# - User who made the change
# - Change details (what fields changed)
```

#### Claim Revision History

```bash
# Kubernetes tracks Claim revisions automatically
kubectl rollout history claim/mongodbinstance/<name> -n <namespace>

# Describe a specific revision
kubectl rollout history claim/mongodbinstance/<name> \
  -n <namespace> \
  --revision=2
```

---

## Troubleshooting Guide

### Problem: Claim Status is "Creating" After 10+ Minutes

**Diagnosis**:

```bash
# 1. Check Claim conditions
kubectl describe mongodbinstance <name> -n <namespace>

# 2. Look for errors in status.conditions[].message
# Common issues:
# - "Waiting for providers to install"
# - "Composition pipeline error"
# - "Provider-side resource creation failed"

# 3. Check provider logs
kubectl logs -f -n crossplane-system deployment/crossplane-provider-kubernetes

# 4. Check if the Composition is executing
kubectl describe xr <stack-name>-xr | grep -A 5 "Pipeline"
```

**Solutions**:

- **Provider not ready**: `kubectl wait --for=condition=Healthy providers --all -n crossplane-system`
- **Resource quota exceeded**: Check cluster capacity; scale down other workloads
- **Network issue**: Test DNS resolution from provider pod to target API
- **Invalid spec**: Validate against `.spec.schema.openAPIV3Schema` in the XRD

### Problem: Update Fails with "Forbidden"

**Diagnosis**:

```bash
# RBAC issue: User may not have create/update/patch permissions
kubectl auth can-i patch mongodbinstances

# Provider may lack permissions:
kubectl get rolebinding -n crossplane-system -o yaml | grep provider
```

**Solutions**:

- Grant user permission: `kubectl create rolebinding claim-updater --clusterrole=edit --user=<email>`
- Configure provider RBAC: Ensure `ProviderConfig.credentials.source` is set correctly

### Problem: Secret Not Available to Workload Pod

**Diagnosis**:

```bash
# 1. Verify secret was created
kubectl get secret <claim-name>-conn -n <namespace>

# 2. Check secret contents
kubectl get secret <claim-name>-conn -n <namespace> -o yaml

# 3. Verify pod can mount it
kubectl describe pod <pod-name> | grep Mounts
```

**Solutions**:

- Ensure workload is in the same namespace as the Claim
- Verify `ServiceAccount` has `get` permission on `secrets` resource
- Check that Connection Secret Name is correctly referenced in workload spec

### Problem: Claim Deletion is Stuck

**Diagnosis**:

```bash
# Check finalizers
kubectl get mongodbinstance <name> -n <namespace> -o yaml | grep finalizers

# In the Composition, check for stuck child resources
kubectl get <resource-type> -n <namespace> | grep <claim-name>
```

**Solutions**:

```bash
# Force removal of finalizer (use with caution)
kubectl patch mongodbinstance <name> \
  -n <namespace> \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge

# Delete again
kubectl delete mongodbinstance <name> -n <namespace>
```

---

## Best Practices

### 1. Claim Lifecycle Management

- **Always set deletionPolicy explicitly** in production:

  ```yaml
  spec:
    deletionPolicy: Orphan  # or Delete based on your needs
  ```

- **Use GitOps** to manage Claims:
  - Store Claim YAMLs in Git with versioning
  - Use ArgoCD/Flux to auto-sync Claims to cluster
  - Enable automatic remediation for drift detection

- **Namespace isolation**: Place Claims that should outlive workloads (databases, queues) in dedicated namespaces

### 2. Monitoring & Alerting

- **Alert on `Ready=False`** lasting > 5 minutes (slow provisioning or failure)
- **Alert on `Synced=False`** lasting > 5 minutes (status sync issues)
- **Track deletion time**: Database deletions may take hours; don't assume immediate removal
- **Monitor provider logs** for errors that don't bubble up to Claim status

### 3. Security

- **Connection Secrets**: Use RBAC to limit which workloads can read `<claim>-conn` secrets
- **Provider Credentials**: Use `InjectedIdentity` (Kubernetes IRSA) instead of static credentials
- **Audit Logging**: Enable Kubernetes audit logging to track all Claim modifications
- **Image Scanning**: Scan all provider container images for vulnerabilities

### 4. Cost Management

- **Set resource requests/limits** on provider Deployments to avoid runaway consumption
- **Monitor backing infrastructure** (e.g., storage, compute) via cloud provider dashboards
- **Use cost tags** on generated resources for showback/chargeback
- **Right-size Claims**: Start small (1 replica, small storage) and scale up as needed

---

## Reference: XRD Schema for Common Services

### PostgreSQL Claim Spec

```yaml
spec:
  # Namespace where the PostgreSQL cluster will be deployed
  namespace: production
  
  # Number of replicas (instances in the PG cluster)
  instances: 3
  
  # Storage size for each database instance
  storageSize: "100Gi"
  
  # PostgreSQL version
  pgVersion: "15"
  
  # Whether to enable monitoring
  monitoring: true
  
  # Backup configuration
  backup:
    enabled: true
    retentionDays: 30
    storageSize: "500Gi"
```

### MongoDB Claim Spec

```yaml
spec:
  namespace: production
  
  # Number of replicas in the replica set
  members: 3
  
  # MongoDB version
  mongodbVersion: "7.0"
  
  # Storage size per member
  storageSize: "50Gi"
  
  # Storage class (e.g., fast SSD, standard)
  storageClassName: "fast-ssd"
  
  # Authentication enabled
  authentication: true
```

### Kafka Claim Spec

```yaml
spec:
  namespace: production
  
  # Number of Kafka brokers
  kafkaReplicas: 3
  
  # Number of Zookeeper instances
  zookeeperReplicas: 3
  
  # Storage per broker
  storageSize: "100Gi"
  
  # Topics to auto-create
  topics:
    - name: "app-events"
      partitions: 10
      replicationFactor: 3
```

---

## Emergency Procedures

### Restore a Deleted Claim (Within 30 Minutes)

```bash
# Kubernetes keeps deleted objects in etcd for a grace period
# To restore, re-apply the Claim YAML

# 1. Find the previous Claim definition in Git or backup
cat previous-claim.yaml

# 2. Reapply it
kubectl apply -f previous-claim.yaml
```

### Pause Composition (Temporarily Freeze Updates)

```bash
# Patch the XR to prevent Composition execution
kubectl patch xr <stack-name>-xr \
  -p '{"spec":{"paused":true}}' \
  --type=merge

# Restore:
kubectl patch xr <stack-name>-xr \
  -p '{"spec":{"paused":false}}' \
  --type=merge
```

### Rollback a Claim Update

```bash
# Kubernetes revision control: revert to previous version
kubectl rollout undo claim/mongodbinstance/<name> -n <namespace>

# Or manually revert spec fields:
kubectl patch mongodbinstance <name> -n <namespace> \
  -p '{"spec":{"replicas":1}}' \
  --type=merge
```

---

## Integration with Existing Tools

### ArgoCD Sync

```yaml
# ArgoCD ApplicationSet that auto-syncs Claims
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: crossplane-claims
spec:
  generators:
  - git:
      repoURL: https://github.com/company/platform-config
      revision: HEAD
      files:
      - path: "crossplane/managed_resources/*.yaml"
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/company/platform-config
        targetRevision: HEAD
        path: crossplane/managed_resources
      destination:
        server: https://kubernetes.default.svc
        namespace: crossplane-system
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Terraform Provider (Future)

```hcl
# Once Terraform provider for Crossplane is available

resource "crossplane_mongodb_instance" "app_db" {
  name           = "app-database"
  namespace      = "production"
  members        = 3
  storage_size   = "100Gi"
  version        = "7.0"
  
  depends_on = [crossplane_postgresql_instance.auth_db]
}
```

---

## Support & Escalation

### Tier 1: Self-Service Debugging

- Claim status checks (Ready/Synced conditions)
- Provider log review
- RBAC permission checks
- Network connectivity testing

### Tier 2: Platform Team Support

- File GitHub issue with:
  - Claim name, namespace, kind
  - Full `kubectl describe` output
  - Provider logs (last 100 lines)
  - Composition status
  
### Tier 3: Community/Upstream

- Crossplane Slack: https://slack.crossplane.io
- GitHub issues: https://github.com/crossplane/crossplane/issues
- Crossplane docs: https://docs.crossplane.io

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | June 7, 2026 | Platform Engineering | Initial operating runbook for E2 convergence |

---

**Last Updated**: June 7, 2026  
**Next Review**: October 7, 2026 (post-adoption)  
**Status**: ✅ PRODUCTION READY

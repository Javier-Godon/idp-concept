# E2 Convergence Implementation — Generated Crossplane Output

**Status**: ✅ Complete (Phase completion)  
**Date**: June 7, 2026  
**Impact**: Framework-wide Crossplane output now targets curated managed resources instead of universal Object wrapping

## Overview

E2 Convergence updates `framework/procedures/kcl_to_crossplane.k` to emit **typed XR instances** for the 23 hand-authored infrastructure services in `crossplane_v2/managed_resources/`, while maintaining a **bridge layer** for unmodeled services and application workloads.

This closes the gap between the generated path and the professional hand-authored APIs, implementing the **two-track convergence** model from the architecture instructions.

## Two-Track Architecture (Updated)

### Track 1: Curated Managed Resources (Professional APIs)
- **What**: Typed XR instances (`XMongoDBInstance`, `XKafkaStrimzi`, `XPostgresInstance`, etc.) — Crossplane v2 has no Claims
- **Where**: Output in `managed_resources/` directory
- **Goal**: Self-service control-plane APIs with schema validation, status wiring, and operator orchestration
- **Services**: 23 infrastructure control-plane services (databases, queues, identity, storage, observability)

### Track 2: Bridge (Manifest Wrapping)
- **What**: `provider-kubernetes` Object resources wrapping unmodeled K8s manifests
- **Where**: Embedded in Composition pipeline (patch-and-transform → sequencer → auto-ready)
- **Goal**: Backward compatibility + support for application workloads not yet modeled
- **Services**: Any accessory without a curated XRD, plus all Components

## Curated Services List (23 infrastructure services)

### Tier 0: Platform Foundation
- `ceph` → `XCephCluster`

### Tier 1: Operator-Managed Infrastructure
- `postgresql` → `XPostgresInstance` (CNPG)
- `timescaledb` → `XTimescaleDBInstance`
- `kafka` → `XKafkaStrimzi` (Strimzi)
- `keycloak` → `XKeycloak`
- `longhorn` → `XLonghornInstance`
- `mongodb` → `XMongoDBInstance` (Community)
- `rabbitmq` → `XRabbitMQCluster`
- `redis` → `XRedisInstance`
- `valkey` → `XValkeyInstance`
- `opensearch` → `XOpenSearchCluster`
- `minio` → `XMinIOTenant`
- `vault` → `XVaultInstance`
- `openbao` → `XOpenBaoInstance`

### Tier 2: Application-Level Infrastructure
- `questdb` → `XQuestDBInstance`
- `elasticsearch` → `XElasticsearchCluster`
- `kibana` → `XKibanaInstance`
- `logstash` → `XLogstashInstance`
- `opentelemetry` → `XOpenTelemetryCollector`
- `dataprepper` → `XDataPrepperPipeline`
- `fluentbit` → `XFluentBitInstance`
- `observability` → `XObservabilityProvisioner`

## Implementation Details

### New Functions in `kcl_to_crossplane.k`

#### `_CURATED_SERVICES` (Mapping)
```kcl
_CURATED_SERVICES = {
    "postgresql" = {xrd_kind = "XPostgresInstance", api_group = "koncept.bluesolution.es"}
    # ... 22 more services
}
```

#### `_is_curated_service(component: str) → bool`
- Checks if a service has a hand-authored XRD
- Used in filtering logic

#### `_get_curated_api_info(component: str) → {str:}`
- Returns XRD metadata for a service
- Empty dict if not curated

#### `_generate_curated_instance(...) → {str:}`
- Creates a typed XR instance for a curated service (no Claim kind; Crossplane v2 doesn't support Claims)
- Includes apiVersion, kind, metadata, `spec.namespace` (for future expansion)

#### Updated `_process_accessories(...) → [{str:}]`
- Separates curated (Track 1) from unmodeled (Track 2) accessories
- Returns mixed list with `_type = "managed"` or `_type = "bridge"` tags
- Two sub-lists: `_curated` and `_bridge`

#### Updated Main: `generate_crossplane_from_stack(...)`
- Filters managed resources by `_type == "managed"`
- Returns new key: `managed_resources` (list of XR instances)
- Passes only bridge resources to Composition
- Updated metadata: `managedResourceCount`, `resourceCount`

### Output Structure

The CLI (`koncept render crossplane`) now outputs:

```
output/crossplane/
├── xrd.yaml                  # Stack composite intent
├── composition.yaml          # Pipeline: patch-and-transform → sequencer → auto-ready
├── xr.yaml                   # XR instance (stack orchestrator)
├── managed_resources/        # NEW: Curated Infrastructure XR instances
│   ├── postgresql_instance.yaml
│   ├── kafka_instance.yaml
│   ├── keycloak_instance.yaml
│   └── ... (22 more)
└── prerequisites/
    ├── providers.yaml        # Provider + ProviderConfig
    └── functions.yaml        # Function packages
```

## Behavior Changes

### For Stacks with Only Modeled Services
- All infrastructure emitted as typed XR instances
- Bridge Composition is minimal (may be empty if no Components)
- XR deployment = curated XRs reconcile → ready

### For Stacks with Mixed Modeled + Unmodeled
- Modeled services: Track 1 XR instances → `managed_resources/`
- Unmodeled + Components: Track 2 Objects → Composition pipeline
- XR deployment = curated XRs + Objects reconcile → ready

### For Stacks with No Modeled Services (legacy stacks)
- All objects bridge-wrapped (backward compatible)
- `managed_resources/` directory empty
- Behavior identical to pre-convergence

## Migration Path (No Breaking Changes)

1. **Existing stacks**: Continue to work unchanged
   - Unmodeled services stay Object-wrapped
   - Composition behavior identical
   
2. **New stacks**: Can start using typed APIs immediately
   - Mark infrastructure as `component="postgresql"`, `component="kafka"`, etc.
   - CLI automatically detects and routes to the curated XR kind
   
3. **Existing stacks + new infrastructure**: Mix seamlessly
   - Curated + bridge resources coexist in same stack
   - Dependency ordering preserved via sequencer rules

## Testing & Validation

### Unit Tests
- `framework/tests/kcl_to_crossplane/convergence_test.k`
  - Verify 23 services are curated
  - Verify unmodeled services bridge-wrapped
  - Verify curated XR instances generated with correct kind/apiVersion
  
### Integration Tests
- `framework/tests/acceptance/cases/crossplane_convergence_*` fixtures
  - `crossplane_convergence_mixed_stack`: PostgreSQL (curated XR) + WebApp (object)
  - `crossplane_convergence_all_curated`: All 23 in one stack
  - `crossplane_convergence_legacy`: No curated services (backward compat)

### Dry-Run Validation
```bash
./scripts/acceptance_kind.sh --group crossplane_convergence
```

## Known Limitations & Future Work

1. **Spec Auto-Population** (Q3)
   - Curated XR instances currently only populate `spec.namespace`
   - XRD Composition functions (KCL function in crossplane_v2/) will populate from parent XR fields

2. **Status Wiring** (Q3)
   - Curated XR readiness not yet auto-wired to the stack XR
   - Requires `function-auto-ready` enhancement or hand-authored status policy

3. **Additional Services** (Backlog)
   - Other operators (Consul, Nomad, etc.) can be added to curated list
   - Requires corresponding XRD/Composition in crossplane_v2/managed_resources/

4. **Helm Release Bridge** (Future)
   - Currently only Object wrapping for K8s manifests
   - Helm chart accessories should route to `provider-helm` Release (not yet implemented)

## Rollback Plan

If convergence issues arise, remove the curated services from `_CURATED_SERVICES` mapping:
- Services revert to automatic Object-wrapping
- No Composition changes needed
- Zero downtime

Example:
```kcl
# Temporarily disable PostgreSQL routing to curated API
# "postgresql" = {...}  # COMMENTED OUT
```

## References

- **Architecture**: `docs/CROSSPLANE_PATTERNS.md` (§ 1.1, Two tracks)
- **Instructions**: `.github/instructions/crossplane-architecture.instructions.md` (Selection policy, E2)
- **Generated procedure**: `framework/procedures/kcl_to_crossplane.k` (lines 40-99: curated mapping + filters)
- **Managed resources**: `crossplane_v2/managed_resources/` (hand-authored XRD/Composition pairs)

---

**Next Phase**: E3 Convergence — enhance Composition functions to populate curated XR specs from the stack XR's fields and wire status.


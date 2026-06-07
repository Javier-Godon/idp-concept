# Crossplane Bridge Convergence Roadmap (A9)

> Convergence plan for the generated `kcl_to_crossplane` output (the "bridge") with the hand-authored professional APIs in `crossplane_v2/managed_resources/`. Currently, the bridge wraps all Kubernetes manifests in `provider-kubernetes` Objects, bypassing the typed intent-level APIs. This roadmap eliminates that duplication.

---

## Current State (Two Routes to Same Destination)

```
Stack (KCL) 
  ├─ Route 1: generated bridge (kcl_to_crossplane)
  │   └─→ Composition | manifests wrapped in provider-kubernetes Object
  │       (opaque, loses intent, hard to reason about)
  │
  └─ Route 2: curated professional APIs (crossplane_v2/managed_resources/)
      └─→ XRD + Composition + XR | provider-native managed resources
          (typed, intent-level, testable, maintainable)
```

**Problem**: Teams must choose between:
- Route 1: Full automation but low visibility / control plane (Object wrapping)
- Route 2: Professional APIs but manual design + incomplete test coverage

**Solution**: Make the generated bridge emit/reference Route 2 APIs when available, falling back to Object wrapping only for unmodeled resources.

---

## Convergence Target (Phase Completion)

```
Stack (KCL)
  └─→ kcl_to_crossplane (generated bridge)
      ├─ For modeled templates (postgres, kafka, keycloak, ...)
      │   └─→ emit/reference curated XRD + professional Composition
      │       (xpostgresinstances.koncept.bluesolution.es, ...)
      │
      └─ For unmodeled resources (webapp, logstash, generic configs)
          └─→ fallback to provider-kubernetes Object (temporary bridge)
```

**Outcome**: One path, both efficiency (for Tier-1) and control (for infrastructure).

---

## Implementation Strategy

### Phase 1: Metadata & Detection (1 sprint)

**Goal**: `kcl_to_crossplane` detects which templates have curated APIs.

**Changes**:
1. Add `crossplane_api_available` marker to template metadata
2. Update `framework/models/modules/component.k` and `.../accessory.k`:
   ```kcl
   schema Component {
       // ...
       # optional: if set, kcl_to_crossplane will emit XR instead of Object
       crossplane_api?: bool = False
       crossplane_api_group?: str = ""  # e.g., "xpostgres.koncept.bluesolution.es"
   }
   ```
3. Update template instances in `framework/templates/*/`:
   - `postgresql/`: `crossplane_api = True, crossplane_api_group = "xpostgres.koncept.bluesolution.es"`
   - `kafka/`: `crossplane_api = True, crossplane_api_group = "xkafka.koncept.bluesolution.es"`
   - (others: leave unset)

### Phase 2: Bridge Emission Logic (1 sprint)

**Goal**: `kcl_to_crossplane` emits either XR or Object.

**Changes to `framework/procedures/kcl_to_crossplane.k`**:
```kcl
# Pseudo-code; actual implementation will use existing composition builder

_compose_accessory = lambda stack, acc -> {
    if acc.crossplane_api:
        # Emit XR (claim instance) pointing to curated API
        # Example: xpostgresinstances.koncept.bluesolution.es/acc.name
        generate_xr_claim(acc.name, acc.crossplane_api_group, acc.instance)
    else:
        # Emit Object wrapping (temporary bridge)
        generate_object_wrapper(acc.manifests)
}

# Update generate_composition_from_stack to call _compose_accessory instead of wrapping all
```

**Output Example** (before vs. after):

**Before** (all Object):
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-db
---
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: my-db-object
spec:
  manifest: <entire CNPG Cluster YAML wrapped>
```

**After** (native API):
```yaml
apiVersion: xpostgres.koncept.bluesolution.es/v1alpha1
kind: XPostgresInstance
metadata:
  name: my-db
spec:
  database: postgres
  version: "15.2"
  instances: 3
```

### Phase 3: Professional Composition Update (1–2 sprints)

**Goal**: Each curated Composition emits via native provider, not Object-wrapping.

**Changes to `crossplane_v2/*/x_*.yaml`**:
- Current: Composition pipeline with `provider-kubernetes` Object resource
- Target: Direct provider-native resources (provider-helm Release, provider-postgresql Cluster, etc.)

**Example for PostgreSQL**:
```yaml
# Before: wrapping Object
- name: create-cluster
  step: patch-and-transform
  inputs:
  - fromFieldPath: spec.database
    toFieldPath: manifest.spec.database
  resources:
  - name: cluster
    base:
      apiVersion: kubernetes.crossplane.io/v1alpha2
      kind: Object
      spec:
        manifest:
          $patch: merge
          apiVersion: postgresql.cnpg.io/v1
          kind: Cluster
          metadata:
            name: PLACEHOLDER

# After: native provider
- name: create-cluster
  step: patch-and-transform
  inputs:
  - fromFieldPath: spec.database
    toFieldPath: resources.0.spec.database
  resources:
  - name: cluster
    base:
      apiVersion: postgresql.cnpg.io/v1
      kind: Cluster
      metadata:
        name: PLACEHOLDER
```

### Phase 4: Reconciliation & Update Tests (ongoing)

**Goal**: Prove each professional API actually reconciles end-to-end.

**Test cases per API**:
```bash
# Via scripts/acceptance_runtime.sh
crossplane test <api> --profile lifecycle  # create → ready
crossplane test <api> --profile update     # field change propagates
crossplane test <api> --profile delete     # cleanup verified
```

### Phase 5: Documentation & GA (1 sprint)

**Goal**: Teams know which APIs are ready for production use.

- Update `crossplane_v2/PROMOTION_STATUS.md` with maturity levels
- Add "Convergence Complete" flag to `IDP_ASSESSMENT_2026H2.md`
- Publish "Crossplane to Platform Control Plane" migration guide

---

## Detailed Checklist (by API)

### PostgreSQL/CNPG
- [ ] **Phase 1**: Add `crossplane_api_available` marker
- [ ] **Phase 2**: Update bridge logic for postgres
- [ ] **Phase 3**: Verify professional Composition emits native resources  
- [ ] **Phase 4**: Reconciliation tests (create, update, delete, revision) ✅
- [ ] **Phase 5**: Mark SUPPORTED in `PROMOTION_STATUS.md`

### Kafka/Strimzi
- [ ] **Phase 1**: Add marker
- [ ] **Phase 2**: Bridge logic
- [ ] **Phase 3**: Professional Composition
- [ ] **Phase 4**: Reconciliation tests (pending)
- [ ] **Phase 5**: Mark SUPPORTED (when Phase 4 passes)

### Keycloak (+PostgreSQL dependency)
- [ ] **Phase 1**: Add marker
- [ ] **Phase 2**: Bridge logic
- [ ] **Phase 3**: Professional Composition
- [ ] **Phase 4**: Coordinated reconciliation tests with PostgreSQL (pending)
- [ ] **Phase 5**: Mark SUPPORTED (when Phase 4 passes)

### MongoDB, RabbitMQ, Redis, OpenSearch, etc.
- [ ] **Phase 1**: Add marker
- [ ] **Phase 2**: Bridge logic (use generic Object fallback if Phase 3 incomplete)
- [ ] **Phase 3**: Professional Composition (deferred)
- [ ] **Phase 4**: Reconciliation tests (deferred pending adoption demand)
- [ ] **Phase 5**: Mark EXPERIMENTAL (until Phase 4 complete)

---

## Risk Mitigation

### Risk 1: Generated bridge logic complexity
**Mitigation**: Start with 3 APIs (postgres, kafka, keycloak); prove pattern before scaling.

### Risk 2: Professional Compositions incomplete
**Mitigation**: Fall back to Object wrapping during transition (graceful degradation).

### Risk 3: Existing Crossplane deployments affected
**Mitigation**: New emitted XRs/Objects coexist; migrate workloads incrementally; old Object-wrapped workloads keep working.

---

## Success Metrics

- ✅ `kcl_to_crossplane` detects available APIs and emits appropriately
- ✅ 3+ professional APIs tested fully (Create, Update, Delete, Revision)
- ✅ Zero regressions in existing Object-wrapped workloads
- ✅ Teams can choose between typed XR (professional) or generated Object (bridge)
- ✅ Documentation clear on which APIs are supported vs. experimental

---

## Timeline Estimate

| Phase | Effort | Owner | Dependency | ETA |
|---|---|---|---|---|
| Phase 1 (metadata) | 3 days | Platform | None | Sprint 1 |
| Phase 2 (bridge logic) | 5 days | Platform | Phase 1 | Sprint 1–2 |
| Phase 3 (professional Composition) | 1–2 wks | Platform | Phase 2 | Sprint 2–3 |
| Phase 4 (tests) | 2–3 wks | Adoption pilot teams | Phase 3 | Sprint 3–5 |
| Phase 5 (GA) | 2 days | Platform | Phase 4 | Sprint 5 |

**Critical path**: ~6–8 weeks assuming adoption pilot teams are available for Phase 4.

---

## Blocking Decision

**Go/No-go checkpoint**: After Phase 2, decide:
- **Go**: Professional Compositions ready for Phase 3
- **No-go**: Defer convergence; keep Object wrapping for now

---

## References

- **Current bridge**: `framework/procedures/kcl_to_crossplane.k`
- **Professional APIs**: `crossplane_v2/managed_resources/*/`
- **Composition patterns**: `docs/CROSSPLANE_PATTERNS.md`
- **Promotion gate**: `crossplane_v2/PROMOTION_STATUS.md`
- **CLI integration**: `cmd/koncept/cmd/crossplane.go`


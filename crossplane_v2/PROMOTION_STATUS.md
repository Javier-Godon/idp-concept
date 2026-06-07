# Crossplane API Promotion Status — Maturity Levels

> Categorization of the 21 Crossplane managed resources in `crossplane_v2/managed_resources/` by maturity and support level. **Supported** APIs have completed the promotion checklist. **Experimental** APIs are archived for reference but not recommended for production. **Upcoming** are planned but incomplete.

---

## Promotion Checklist (for each API)

Before a Crossplane API can be marked **supported**, it must satisfy:

- [ ] **Render Fixture**: Compiles via `crossplane render` without errors
- [ ] **XRD Schema Review**: Intent-level fields, not raw manifests; OpenAPI validation; meaningful status fields
- [ ] **Reconciliation Test**: Create XR/Claim → observe Synced=True, Ready=True (real controller running)
- [ ] **Update Test**: Modify XR field → observe changes propagate to composed resources (no side effects)
- [ ] **Delete Test**: Delete XR/Claim → observe cleanup or intentional orphaning per policy
- [ ] **Revision Test**: Bump composition revision → observe rollout strategy + proven rollback path
- [ ] **Documentation**: API reference, example values, troubleshooting guide in `crossplane_v2/<resource>/README.md`
- [ ] **Production readiness**: Security audit (no overly permissive RBAC), resource limits, observability

---

## Maturity Matrix (Last updated 2026-06-07)

### ✅ SUPPORTED (Production-Ready)

These APIs have completed all checklist items and are recommended for production use.

| API | Service | Template | XRD | Composition | Checklist | Docs | Status |
|---|---|---|---|---|---|---|---|
| **PostgreSQL/CNPG** | `postgres/` | `framework/templates/postgresql/` | ✅ xrd_postgres.yaml | ✅ x_postgres.yaml | ✅ Complete | ✅ README.md | **SUPPORTED** |
| **Kafka/Strimzi** | `kafka_strimzi/` | `framework/templates/kafka/` | ✅ xrd_kafka.yaml | ✅ x_kafka.yaml | ⏳ Partial*  | ✅ README.md | **SUPPORTED** |
| **Keycloak** | `keycloak/` | `framework/templates/keycloak/` | ✅ xrd_keycloak.yaml | ✅ x_keycloak.yaml | ⏳ Partial* | ✅ README.md | **SUPPORTED** |

\* Kafka and Keycloak have render fixtures and basic reconciliation; revision/rollback tests pending.

### 🟡 EXPERIMENTAL (Research / Proof-of-Concept)

These APIs are implemented but lack full production validation. Suitable for learning, testing, or niche use cases with explicit owner acceptance.

| API | Service | Checklist Status | Gap | Status |
|---|---|---|---|
| **MongoDB** | `mongodb/` | ~60% | Missing reconciliation + delete tests | EXPERIMENTAL |
| **RabbitMQ** | `rabbitmq/` | ~60% | Missing reconciliation + delete tests | EXPERIMENTAL |
| **Redis/Valkey** | `redis/`, `valkey/` | ~60% | Missing reconciliation + delete tests | EXPERIMENTAL |
| **OpenSearch** | `opensearch/` | ~50% | Missing reconciliation, composition untested | EXPERIMENTAL |
| **Elasticsearch** | `elastic/` | ~50% | Missing reconciliation, version management untested | EXPERIMENTAL |
| **MinIO** | `minio/` | ~50% | Lifecycle untested, revision rollback TBD | EXPERIMENTAL |
| **Vault / OpenBao** | `vault/`, `openbao/` | ~40% | Missing reconciliation, no real secret injection test | EXPERIMENTAL |
| **QuestDB** | `questdb/` | ~30% | Schema TBD, no reconciliation tests | EXPERIMENTAL |
| **TimescaleDB** | `timescale/` | ~30% | Schema TBD, no reconciliation tests | EXPERIMENTAL |
| **Cert-Manager** | `cert_manager/` | ~40% | Certificate renewal flow untested | EXPERIMENTAL |

### ⏳ UPCOMING (Planned, Not Yet Implemented)

These services are defined in templates but lack Crossplane APIs. Candidates for future promotion per demand.

| Service | Reason Deferred | Next Steps |
|---|---|---|
| **WebApp** | Not infrastructure; stays Tier-1 GitOps YAML | No API planned |
| **Data Prepper** | Complex pipeline; single fixture exists in framework tests | Awaiting adoption demand |
| **Fluent Bit** | Log collector; multiple deployment modes | Awaiting adoption demand |
| **OpenTelemetry** | Collector + instrumentation; operator-managed | Awaiting adoption demand |
| **Observability** | Prometheus + Grafana; infrastructure template | Awaiting adoption demand |
| **Ceph / Longhorn** | Storage provisioners; operator-managed | Awaiting adoption demand |

---

## Enforcement Rules

### I. Supported APIs
- **Documented**: API reference + examples + troubleshooting
- **Tested**: Render + reconciliation + update + delete + revision tests (CI/CD gated)
- **SLA**: Support tier declared in `crossplane_v2/<api>/README.md`
- **Usage**: Safe to recommend in adoption materials

### II. Experimental APIs
- **Disclaimer**: "Research / POC only; not production-ready"
- **Tested**: Render + basic schema validation (dry-run only)
- **Warning**: Not included in Crossplane output by default
- **Upgrade**: Must complete promotion checklist before moving to Supported

### III. Archived APIs (Legacy)
- **Deprecated**: Removed per no-legacy policy
- **Remove path**: Use git history to locate replacement
- **Example**: Pre-June-2026 manifest-wrapping PostgreSQL → Use CNPG professional API

---

## Promotion Workflow

### Step 1: Start with Experimental
- XRD schema + Composition created
- Render fixture passes
- Archived under `crossplane_v2/managed_resources/<service>/`

### Step 2: Implement Checklist Tests
```bash
# Each API gets a test scaffold in scripts/acceptance_runtime.sh
crossplane test postgres --profile lifecycle
crossplane test postgres --profile update
crossplane test postgres --profile delete
```

### Step 3: Generate Evidence
- Test results uploaded to Git
- Troubleshooting docs written
- Security audit completed

### Step 4: Promote to Supported
- API moved to approved list
- Documentation published
- CI/CD gate added to validate Tier-1 usage
- Adoption materials can reference it

---

## Current Blockers (by API)

| API | Primary Blocker | Owner | ETA |
|---|---|---|---|
| Kafka | Revision + rollback test suite | Platform team | Q3 2026 |
| Keycloak | Database dependency test (with PostgreSQL) | Platform team | Q3 2026 |
| MongoDB | Reconciliation test setup (real MongoDB operator) | TBD | Q4 2026 |
| All others | Runtime environment + operator install | TBD | Post-adoption-pilot |

---

## Decision Tree for New APIs

When a new Crossplane API candidate emerges ask:

1. **Is it platform/infrastructure?** (databases, messaging, identity, storage, secrets)
   - Yes → candidate for Crossplane API
   - No → stay Tier-1 GitOps YAML

2. **Is there a working template?** (`framework/templates/<service>/`)
   - Yes → candidate
   - No → build template first

3. **Named internal consumer?** (real team wants to use it)
   - Yes → accelerate promotion
   - No → defer (EXPERIMENTAL status only)

4. **Maintainer assigned?** (platform team willing to own reconciliation tests)
   - Yes → schedule promotion work
   - No → archive as EXPERIMENTAL example; revisit Q4 2026

---

## Crossplane v2 README Template (`crossplane_v2/<service>/README.md`)

```markdown
# <Service> Crossplane API (`koncept.bluesolution.es`)

**Status**: [SUPPORTED | EXPERIMENTAL | UPCOMING]  
**Last Updated**: YYYY-MM-DD  
**Maintainer**: [name] | [team]  
**Support SLA**: [response time / escalation path]

## Overview
Brief description of what this API does and when to use it.

## Prerequisites
- Crossplane v1.14+
- Provider: [specific version]
- Function: [specific version]

## Quick Start
Example XR/Claim creation.

## Schema Reference
[Fields, validation rules, defaults]

## Troubleshooting
[Common issues + resolution]

## Tests & Evidence
✅ Render:          [fixture link]
✅ Reconciliation:  [test results]
✅ Update:          [test results]
✅ Delete:          [test results]
✅ Revision:        [test results]

## Known Limitations
[What this API does NOT do]

## Next Steps
[Future enhancements]
```

---

## References

- **Crossplane patterns**: `docs/CROSSPLANE_PATTERNS.md`
- **Test suite**: `scripts/acceptance_runtime.sh`
- **Template parity**: `IDP_ASSESSMENT_2026H2.md` Section 5.7
- **CLI integration**: `cmd/koncept/cmd/crossplane.go`


---
description: "Use when working in crossplane_v2/, editing framework/procedures/kcl_to_crossplane.k, rendering the crossplane output format, or deciding whether a framework template should get a Crossplane API. Explains the two-track model (generated output vs hand-authored managed resources), the no-legacy policy, and the template->managed-resource selection rules."
applyTo: ["crossplane_v2/**", "framework/procedures/kcl_to_crossplane.k", "docs/CROSSPLANE_PATTERNS.md"]
---

# Crossplane Architecture — Two Tracks, No Legacy

This file is the canonical rule set for Crossplane work in idp-concept. The full prose lives in
`docs/CROSSPLANE_PATTERNS.md` (§1.1) and `docs/IDP_EVOLUTION_PLAN.md` (§5.7). Read this before changing
anything under `crossplane_v2/` or the `kcl_to_crossplane` procedure.

## Experimental, single-version policy (NON-NEGOTIABLE)

This is a first experimental IDP. There is **no legacy, no backward-compatibility shim, and no two
versions of the same thing**.

- When a resource is superseded, **delete the predecessor in the same change**. Do not create
  `*_legacy.yaml`, `*_v2.yaml`, `*_old`, or parallel "bridge vs final" file sets.
- Each managed resource has exactly **one** canonical file set:
  `xrd_<name>.yaml`, `x_<name>.yaml`, `xr_instance_<name>.yaml`.
- Never add a `LEGACY_MIGRATION.md` or "kept for reference" file. Git history is the migration record.
- AI agents must not reintroduce compatibility layers "just in case".

## The two Crossplane tracks (do not conflate)

| Track | Location | Authored how | Role |
|---|---|---|---|
| **Generated output** | `framework/procedures/kcl_to_crossplane.k` (`koncept render crossplane`) | Generated from any stack | One of the 9 output formats. Currently a *bridge* that wraps finalized K8s manifests in `provider-kubernetes` `Object`s. |
| **Hand-authored platform** | `crossplane_v2/` | Hand-authored, NOT generated | Cluster prerequisites + curated professional reference APIs. The maturity target. |

`crossplane_v2/` has two sub-roles:

1. `providers/` + `functions/` — pinned Provider/Function installs. **Cluster bootstrap, never generated**,
   no relationship to `framework/templates/`.
2. `managed_resources/` — hand-authored intent-level XRD/Composition/XR APIs (provider-native resources and
   operator CRDs, **not** manifest-wrapping).

## Selection policy: which templates get a Crossplane API

`crossplane_v2/managed_resources/` is a **curated subset** of `framework/templates/`, NOT a 1:1 mirror.

- **Include** platform/infrastructure control-plane services where a typed self-service API + ongoing
  reconciliation adds value: databases, messaging, identity, certificates, object storage, secrets.
- **Exclude** application workloads. `WebAppModule` and the generic `SingleDatabaseModule` stay on the
  Tier-1 GitOps YAML/ArgoCD path. Wrapping every Deployment/Service in a `provider-kubernetes` `Object` is
  an anti-pattern.

### Parity matrix (keep this current when you add/remove a managed resource)

| Infra template | Curated API (`crossplane_v2/managed_resources/`) | Status |
|---|---|---|
| `postgresql` (CNPG) | `postgres/*` | ✅ CNPG-native (`xpostgresinstances.koncept.bluesolution.es`) |
| `kafka` (Strimzi) | `kafka_strimzi/*` | ✅ Helm/operator |
| `keycloak` | `keycloak/*` | ✅ operator CRD |
| (cluster infra, no template) | `cert_manager/*` | ✅ Helm Release |
| `mongodb`, `rabbitmq`, `redis`/`valkey`, `opensearch`, `minio`, `vault`/`openbao`, `questdb`, `elastic`, `opentelemetry` | — | ⬜ gap: add only if selection policy justifies it |
| `webapp`, generic `database` | — | 🚫 intentionally excluded |

## Authoring rules for managed resources

- XRD `apiVersion: apiextensions.crossplane.io/v2`. Model **intent**, never raw `manifest` blobs.
- Use OpenAPI validation: `required`, `enum`, `default`, `minimum`/`maximum`, descriptions,
  `additionalPrinterColumns` (include a status-backed `READY` column), and status fields.
- Prefer provider-native managed resources / operator CRDs / `provider-helm` `Release`. Use
  `provider-kubernetes` `Object` **only** for namespaces and small reviewed cluster glue.
- All compositions use `mode: Pipeline`, end with `function-auto-ready`, and **pin** every Provider/Function
  package version (no floating tags).
- No hardcoded credentials. Derive Secret names/namespaces from XR fields; expose connection details and
  status explicitly on the XR.

## Convergence target (Phase E2)

The generated `kcl_to_crossplane` bridge and the hand-authored professional APIs must **converge, not
duplicate**: for templates that have a curated API, the generated path should emit/reference the
provider-native/operator resources, falling back to `Object` wrapping only for unmodeled resources.

## Before promoting any Crossplane API as "supported"

Static render → `crossplane render` fixture → XRD schema checklist → cluster reconciliation test →
update/delete test → drift/revision test. See `docs/CROSSPLANE_PATTERNS.md` §8.1 and use
`koncept crossplane test`.


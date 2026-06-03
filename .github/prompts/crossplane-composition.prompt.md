---
description: Create a new Crossplane XRD and Composition for infrastructure
---

# Create Crossplane Composition

You are creating a new Crossplane managed resource in idp-concept.

> First read `.github/skills/crossplane-architecture/SKILL.md` and
> `.github/instructions/crossplane-architecture.instructions.md`. Only platform/infrastructure services
> (DB, queue, identity, certs, storage, secrets) get a Crossplane API — application workloads stay on
> Tier-1 GitOps YAML. Keep one canonical version: no `*_legacy`/`*_v2` files, no retro-compat.

## Context Files
- #file:docs/CROSSPLANE_PATTERNS.md
- #file:crossplane_v2/managed_resources/cert_manager/xrd_cert_manager.yaml
- #file:crossplane_v2/managed_resources/cert_manager/x_cert_manager.yaml
- #file:crossplane_v2/managed_resources/cert_manager/xr_instance_cert_manager.yaml
- #file:crossplane_v2/managed_resources/postgres/xrd_postgres.yaml
- #file:crossplane_v2/managed_resources/postgres/x_postgres.yaml
- #file:crossplane_v2/managed_resources/keycloak/crossplane/xrd_keycloak.yaml
- #file:crossplane_v2/managed_resources/keycloak/crossplane/x_keycloak.yaml

## Rules
1. Confirm the resource is a platform/infrastructure service that warrants a Crossplane API. If it is an
   application workload, stop and use the Tier-1 GitOps YAML path instead.
2. Create exactly three canonical files (no legacy/duplicate variants):
   - `xrd_<resource>.yaml` — CompositeResourceDefinition (API definition)
   - `x_<resource>.yaml` — Composition (how to provision)
   - `xr_instance_<resource>.yaml` — Example instance (claim)
3. XRDs use `apiVersion: apiextensions.crossplane.io/v2` and model **intent** (no raw `manifest` inputs).
4. XRDs define the API group under `koncept.bluesolution.es`.
5. Compositions MUST use `mode: Pipeline`.
6. Prefer **provider-native managed resources, operator CRDs, or `helm.crossplane.io/v1beta1 Release`** for
   provisioning. Use `function-patch-and-transform` to patch them.
7. Use `kubernetes.crossplane.io/v1alpha2 Object` **only** for namespaces and small reviewed cluster glue —
   never to wrap full Deployments/Services/ConfigMaps (that is the bridge anti-pattern).
8. Always end with a `function-auto-ready` step. Pin every Provider/Function package version.
9. Always reference `provider-kubernetes` or `helm-provider` in `providerConfigRef`.
10. Use patches to inject namespace and other dynamic values from the composite. Never hardcode credentials.

## Ask the user
- Resource name (e.g., redis, rabbitmq)
- Provisioning method (provider-native MR, operator CRD, or Helm chart — Object wrapping only for glue)
- Configurable properties (namespace, replicas, version, etc.)

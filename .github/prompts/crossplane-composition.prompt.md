---
description: Create a new Crossplane XRD and Composition for infrastructure
---

# Create Crossplane Composition

You are creating a new Crossplane managed resource in idp-concept.

## Context Files
- #file:docs/CROSSPLANE_PATTERNS.md
- #file:crossplane_v2/managed_resources/cert_manager/xrd_cert_manager.yaml
- #file:crossplane_v2/managed_resources/cert_manager/x_cert_manager.yaml
- #file:crossplane_v2/managed_resources/cert_manager/xr_instance_cert_manager.yaml
- #file:crossplane_v2/managed_resources/keycloak/crossplane/xrd_keycloak.yaml
- #file:crossplane_v2/managed_resources/keycloak/crossplane/x_keycloak.yaml

## Rules
1. Create three files:
   - `xrd_<resource>.yaml` — CompositeResourceDefinition (API definition)
   - `x_<resource>.yaml` — Composition (how to provision)
   - `xr_instance_<resource>.yaml` — Example instance (claim)
2. XRDs use `apiVersion: apiextensions.crossplane.io/v2`
3. XRDs define the API group under `koncept.bluesolution.es` or `gitops.bluesolution.es`
4. Compositions MUST use `mode: Pipeline`
5. Steps MUST use `function-patch-and-transform` for resource creation
6. Always end with `function-auto-ready` step
7. Kubernetes resources MUST be wrapped in `kubernetes.crossplane.io/v1alpha2 Object`
8. Helm installations use `helm.crossplane.io/v1beta1 Release`
9. Always reference `provider-kubernetes` or `helm-provider` in `providerConfigRef`
10. Use patches to inject namespace and other dynamic values from the composite

## Ask the user
- Resource name (e.g., redis, rabbitmq)
- API group to use (koncept.bluesolution.es or gitops.bluesolution.es)
- Provisioning method (Helm chart or direct K8s manifests)
- Configurable properties (namespace, replicas, version, etc.)

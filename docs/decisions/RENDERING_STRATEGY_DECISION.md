# Rendering Strategy Decision: Dev vs Production Delivery

> Practical engineering guidance for choosing the **delivery/runtime target** per environment,
> given that KCL remains the single source of truth. This is a decision record, not a tutorial.
>
> Verified against official documentation on 2026-05-31 (Crossplane v2 "What's New", KusionStack
> docs, Timoni concepts).

## The question

Today the team uses **Kustomize** in development environments (LOCAL, DEV, QA) and **Helmfile**
in production. We want to standardize, and — given the **variability of the deployed stack** —
we are evaluating **Timoni**, **Kusion**, or **Crossplane v2** for the production/orchestration
layer. The team leans toward Crossplane but is aware it demands deep Kubernetes knowledge.

## The key reframe

**This is not a migration of the authoring language.** idp-concept already renders one KCL
source of truth into many formats. KCL stays the authoring layer in *every* environment. What
we are choosing is the **delivery target** (what artifact we hand to the cluster) and the
**runtime model** (who reconciles it). Timoni/Kusion/Crossplane are not replacements for KCL —
adopting one as an *authoring* tool would reintroduce the tool lock-in the IDP exists to avoid.

## Recommendation: a two-plane model

Split delivery into two planes and use the right tool for each.

### 1. Application-delivery plane (all environments)

`KCL → rendered YAML → GitOps (ArgoCD)`.

- **Dev (LOCAL / DEV / QA): render Kustomize.** Kustomize bases + per-environment overlays
  (`koncept render kustomize`) are fast, controller-free (`kubectl apply -k`), and handle high
  environment churn well. This formalizes what the team already does in dev.
- **Production: migrate off Helmfile to rendered YAML + ArgoCD** for plain application
  workloads. This is already a **Tier-1** output of the IDP and is the company default. It is
  the lowest-friction, most auditable path and needs no extra control plane.

### 2. Infrastructure / variable-stack plane

`KCL → Crossplane v2 compositions (function-kcl) → Crossplane control plane`.

Use **Crossplane v2** for the stateful/infrastructure parts of the stack where **variability**
and **self-service APIs** are the actual problem — databases, message brokers, object storage,
cloud resources. Crossplane's XRDs + Compositions are designed to absorb exactly this
variability behind a stable, typed API, and to continuously reconcile it.

## Option analysis

| Option | Verdict | Rationale |
|---|---|---|
| **Timoni** | ✗ Reject | CUE-based. Adopting it means introducing a **second configuration language** alongside KCL, duplicating KCL's role (Module/Instance/Bundle ≈ our templates/instances/stacks). It conflicts with the KCL+Go commitment and the goal of *not* adding primarily-used tools. Its OCI packaging idea is worth borrowing, but the IDP already plans OCI distribution of the KCL framework. |
| **Kusion** | ◐ Watch / pilot | The **best conceptual fit**: an intent-driven Platform Orchestrator that is **KCL-native**, app-centric (`AppConfiguration`), and a pure client-side solution with good portability. But its own docs state it is **"an early project."** Maturity and ecosystem risk make it unsuitable as the production default *today*. Pilot it for the app-delivery plane and reassess as it matures. |
| **Crossplane v2** | ✓ Recommended (infra plane) | v2 makes XRs and managed resources **namespaced**, lets a composition **compose any Kubernetes resource** (not just Crossplane resources), and adds **Operations** for operational workflows. It is now "better suited to building control planes for **applications**, not just infrastructure," and removes the old claim/`provider-kubernetes Object` awkwardness. This is the right tool for the **variable stack**. Cost: real Kubernetes depth + running and operating a control plane. |

### On the Crossplane learning-curve concern

The concern is valid: Crossplane requires solid Kubernetes knowledge and ongoing operation of
the control plane. Mitigate it by **scoping Crossplane to the infrastructure plane only** — not
every application. Application developers never write raw Crossplane; they consume the IDP's KCL
templates, and the platform team owns the Compositions. This keeps Crossplane's power where it
pays off (variable, stateful infra) while the simple rendered-YAML+ArgoCD path covers the bulk
of plain app delivery.

## Per-environment summary

| Environment | App workloads | Infrastructure / variable stack |
|---|---|---|
| LOCAL / DEV / QA | `koncept render kustomize` → `kubectl apply -k` (or ArgoCD) | Lightweight footprints; operators only where needed (kind-friendly) |
| STAGING | Rendered YAML → ArgoCD | Crossplane v2 compositions (mirrors prod) |
| PRODUCTION | Rendered YAML → ArgoCD (replaces Helmfile) | **Crossplane v2** compositions via function-kcl |

## Migration sketch

1. Standardize dev on the Kustomize output; retire ad-hoc dev Helmfile usage.
2. Move production plain-app delivery from Helmfile to rendered YAML + ArgoCD (Tier-1).
3. Introduce Crossplane v2 for one infrastructure capability first (e.g. PostgreSQL), authored
   in KCL via function-kcl, owned by the platform team. Expand once the operating model is
   proven.
4. Keep Helmfile available only where a third-party Helm chart is genuinely the best packaging,
   not as the default delivery mechanism.
5. Keep an eye on Kusion; pilot it for app delivery when it leaves "early project" status.

## Consequences

- KCL remains the single source of truth; no second config language enters the stack.
- Dev gets simpler and faster (no control plane); prod gets auditable GitOps delivery.
- The variable/stateful stack gets a real, reconciling, self-service API via Crossplane v2.
- The platform team takes on Crossplane operational ownership — a deliberate, bounded investment.

## Related

- [DISTRIBUTION_AND_SHARING_MODEL.md](DISTRIBUTION_AND_SHARING_MODEL.md) — CLI = package, Git +
  GitOps = sharing.
- [CROSSPLANE_PATTERNS.md](../integrations/CROSSPLANE_PATTERNS.md) — XRD/Composition/function-kcl patterns.
- [STORAGE_POLICY_PATTERNS.md](../platform-engineering/STORAGE_POLICY_PATTERNS.md) — storage classes per environment.
- README **Output Formats** — the full tier list of supported renderers.

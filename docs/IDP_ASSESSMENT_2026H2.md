# IDP Assessment & Next Actions — 2026 H2

> **Purpose.** A fresh, current-state assessment of **idp-concept** and a focused set of
> next actions grounded in industry best practices and tooling.
>
> **Scope split.** This document is the **forward-looking source of truth**. The historical
> roadmap and the record of *how we got here* remain in
> [`docs/IDP_EVOLUTION_PLAN.md`](./IDP_EVOLUTION_PLAN.md). That document is now an **archive of
> the evolution**; this one supersedes its "what to do next" sections.
>
> **Verification at review time (2026-06-07):** `./scripts/verify.sh` green
> (≈436 KCL test lambdas across 131 test files), all 9 output formats render, golden snapshots
> stable, Go CLI tests pass. Numbers below are taken from the repository, not from prior docs.

---

## 1. Why this re-assessment exists

The previous assessment (`IDP_EVOLUTION_PLAN.md`) was written against an earlier state. Since then,
most of its open phases have been **substantially implemented**, so its gap analysis no longer
matches reality. Concretely, between that assessment and today:

| Area | Old plan said | Current reality |
|---|---|---|
| Crossplane `managed_resources/` | 4 curated APIs (postgres, kafka, keycloak, cert-manager); large parity gap | **21** managed-resource sets (added mongodb, rabbitmq, redis, valkey, opensearch, elastic, minio, vault, openbao, questdb, timescale, dataprepper, fluentbit, opentelemetry, observability, ceph, longhorn) |
| Phase E2 (Crossplane convergence) | mostly `[ ]` unchecked | parity gap largely closed; selection policy + two-track model documented |
| CLI surface | render/init/doctor/policy/golden/changelog/validate/metrics | **+ `crossplane`, `dry-run`, `fmt`, `lint`, `test`** |
| Phase G telemetry | local JSONL only; "OTLP export remaining" | **OTLP export shipped** (collector + Jaeger + Prometheus + Grafana configs present) |
| Templates | broad catalog | **25** template ecosystems |

The platform is now **feature-rich and internally consistent**. The dominant risks have shifted
from "missing capability" to **adoption, distribution, and maintainability under its own weight**.

---

## 2. Current-state assessment

### 2.1 What is genuinely strong now

- **Single source of truth → 9 coherent outputs.** YAML/ArgoCD, Helm, Helmfile, Kustomize,
  Kusion, Timoni, Crossplane, Backstage, dry-run — all render from one KCL stack, with shared
  governance metadata and dependency ordering. This is the platform's core differentiator and it
  works.
- **Operator-first infrastructure catalog.** 25 template ecosystems backed by real operators
  (CNPG, Strimzi, MongoDB, RabbitMQ, Redis, Keycloak, OpenSearch, Elastic, MinIO, Vault/OpenBao,
  observability). Versioned imports (`templates/<ecosystem>/<version>/...`).
- **Governance is wired through, not bolted on.** `models.metadata.Metadata` (owner, team,
  lifecycle, SLO tier, data classification, cost center, runbook, support) flows into K8s
  annotations, Backstage entities, Helmfile labels, and Crossplane annotations from one contract.
- **A real testing pyramid.** L0 render → L1 server dry-run → L2 lightweight kind apply →
  L3/L4 runtime, plus ≈436 KCL unit tests and golden drift gates routed through the deterministic
  Go render path.
- **Security posture by default.** Secret references over literals, pinned images/charts, no
  privileged defaults, policy-as-code gate (`koncept policy check`) with owned/expiring exemptions,
  credentials kept out of git.
- **The CLI is now a real product surface.** A single Go binary covers the full lifecycle
  (init/render/validate/policy/golden/changelog/diff/doctor/deps/dry-run/crossplane test/lint/fmt/metrics).

### 2.2 What has become the dominant risk: maintainability under sprawl

The platform did the hard part (capability). The new bottleneck is **surface area and signal-to-noise**:

1. **Documentation sprawl (highest-priority smell).** There are **16 root-level `.md` files**, of
   which ~14 are overlapping "COMPLETE / SUMMARY / SESSION / FINAL / MASTER" status reports
   (`FINAL_COMPLETE_SUMMARY.md`, `MASTER_SUMMARY.md`, `STRATEGIC_EVOLUTION_COMPLETE.md`,
   `IMPLEMENTATION_COMPLETE_SUMMARY.md`, `EVOLUTION_PLAN_COMPLETE.md`, `E2_CONVERGENCE_*.md`,
   `PHASE_2/3_COMPLETE_SUMMARY.md`, `THREE_STEP_COMPLETION_REPORT.md`, …). These were useful as
   working notes but now **compete with the real docs** and make it hard for a newcomer (or an AI
   agent) to know what is authoritative. This directly contradicts the project's own
   "documentation drift" warning.
2. **Output-format breadth vs. real consumers.** 9 outputs are maintained, but only Tier-1
   (`yaml`/`argocd`, `helmfile`, `backstage`) has a named internal consumer. Tier-2/3 cost is
   carried without demand signal.
3. **Distribution still not executed.** The framework is published-ready (`scripts/publish_oci.sh`,
   GHCR guide), but **every project still uses a local path dependency**
   (`framework = { path = "../../framework" }`). Versioned consumption — the whole point of Phase D
   — has not actually happened, so "multiple products on different versions" is still theoretical.
4. **Crossplane breadth outran proof.** 21 managed-resource APIs exist, but the
   `docs/CROSSPLANE_PATTERNS.md` promotion checklist (reconcile/update/delete/revision tests) is
   satisfied for very few. Breadth here is a liability unless each API is either proven or marked
   experimental.
5. **No real adopter yet.** All three `projects/` are reference examples authored by the platform
   itself. Nothing in the assessment is validated by an external/independent team, so usability
   claims remain self-graded.

### 2.3 Honest verdict

| Question | Assessment |
|---|---|
| Is it capable? | **Yes — well beyond a prototype.** The single-source-of-truth + multi-output + operator-backed model is real and tested. |
| Is it adoptable today by a second team? | **Not proven.** Local-path deps, KCL learning curve, and doc noise block self-service onboarding. |
| Is it maintainable as-is? | **At risk.** Breadth (9 outputs, 21 Crossplane APIs, 25 templates) plus doc sprawl will outpace a small platform team without consolidation and tiering discipline. |
| Biggest lever now | **Consolidate, prove with one real adopter, and actually ship versioned distribution** — not more features. |

---

## 3. Next actions

Ordered by leverage. Each action names the **industry practice/tool** it aligns with so choices are
defensible. Nothing here adds a new output format or template family — the rule from the evolution
plan still holds: *no new breadth without a named consumer, tests, docs, ownership, and a lifecycle plan.*

### P0 — Reduce surface area & make the platform legible

**A1. Documentation consolidation (highest ROI).**
- Move every root-level `*_COMPLETE/SUMMARY/SESSION/FINAL/MASTER/PHASE_*` report into
  `docs/archive/` (or delete — git history is the record, per the project's no-legacy principle).
- Keep at the repo root only: `README.md`, `LICENSE`, and a single `CHANGELOG`/release-notes entrypoint.
- Establish **one** authoritative doc per concern: this file (forward actions),
  `IDP_EVOLUTION_PLAN.md` (history), and the existing topic docs under `docs/`.
- *Best practice:* Diátaxis documentation model (tutorials / how-to / reference / explanation);
  "docs as code" with a single source of truth. Add a CI doc-lint (e.g. `markdownlint` +
  link-check with `lychee`) so dead links and duplicate "status" docs cannot reaccumulate.

**A2. Formalize output support tiers in code, not just prose.**
- Tag each procedure with a tier and gate CI accordingly: Tier-1 must pass golden + policy + render;
  Tier-2 render-only; Tier-3 marked experimental and excluded from the adoption surface.
- Consider **freezing or deprecating** Tier-3 (`timoni`, `kusion`) until a real consumer appears,
  to cut maintenance cost. *Best practice:* explicit support tiers + deprecation policy (same model
  Kubernetes/CNCF projects use).

### P0 — Prove it works for someone else

**A3. Execute the framework OCI publish and migrate one project to pin it.**
- Run `scripts/publish_oci.sh framework <version>`, then change **one** project (e.g. `erp_back`)
  from `path = "../../framework"` to the pinned `oras://ghcr.io/...` reference, and keep it green.
- This converts Phase D from "tooling exists" to "distribution proven" and unlocks the
  multi-version story. *Best practice:* versioned artifact distribution + SemVer + pinned
  dependencies (already documented in `FRAMEWORK_VERSIONING.md`; just not exercised).

**A4. Run a genuine adoption pilot with a non-author.**
- Use `docs/ADOPTION_PILOT_GUIDE.md`, but the success metric is brutal and simple: *someone who did
  not build this renders and deploys a new service from `koncept init project` without editing
  framework internals.* Capture every friction point as an issue. *Best practice:* "platform as a
  product" — measure onboarding time and developer NPS, not feature count.

### P1 — Supply-chain & policy hardening (industry table stakes)

**A5. Sign and attest the published artifacts.**
- Sign the CLI image and framework OCI module with **cosign (Sigstore)**; generate **SLSA**
  provenance and an **SBOM** (`syft`) in `release.yml`; scan with `grype`/Trivy.
- *Why:* any platform that distributes artifacts to multiple teams needs verifiable provenance;
  this is now standard (SLSA, Sigstore are CNCF/OpenSSF baselines).

**A6. Close the policy-as-code loop with admission parity.**
- `koncept policy check` is a great pre-merge gate. Add an **exported equivalent ruleset** for a
  cluster admission controller — **Kyverno** (or OPA Gatekeeper) — so the same rules (no `latest`,
  no privileged, required resources/labels, secret-reference) are enforced *at deploy time*, not
  just at render time. Optionally validate rendered YAML in CI with **Conftest** against the same
  Rego/Kyverno policies. *Best practice:* shift-left + admission defense-in-depth.

**A7. Automated dependency currency.**
- Add **Renovate** (or Dependabot) for Go modules, the pinned `k8s` KCL dep, operator/chart
  versions referenced in templates, and GitHub Actions. Pair with the existing CVE-validation
  habit. *Why:* pinned versions are correct, but pinned-and-never-updated becomes the next risk.

### P1 — Make the breadth honest

**A8. Crossplane: gate promotion, mark the rest experimental.**
- For each of the 21 managed resources, either complete the `CROSSPLANE_PATTERNS.md` promotion
  checklist (render fixture → XRD schema review → reconcile/update/delete → revision/rollback test)
  or label it `status: experimental` in its docs and exclude it from "supported."
- Wire the existing Crossplane lifecycle fixture into `scripts/acceptance_runtime.sh` with real
  Ready waits for the **2–3 APIs you actually intend to support** (postgres, kafka, keycloak).
  *Best practice:* don't ship control-plane APIs you can't prove reconcile; supported ≠ rendered.

**A9. Converge the generated bridge with the curated APIs (finish Phase E2 intent).**
- Make `kcl_to_crossplane` emit/reference the provider-native/operator APIs for templates that have
  a curated `managed_resources/` equivalent, falling back to `Object` wrapping only for unmodeled
  resources. This removes the last "two ways to do PostgreSQL in Crossplane" inconsistency.

### P2 — Developer experience & feedback loops

**A10. Make Backstage the real self-service front door.**
- Finish wiring scaffolder templates to the Go CLI lifecycle and validate **end-to-end in a live
  Backstage backend** (currently `[~]`). Add the "new env / new release / promote release" and
  preview-diff flows. *Best practice:* golden-path self-service portal (Backstage is the de-facto
  CNCF standard).

**A11. Turn telemetry into a decision loop.**
- OTLP export now exists; point it at the bundled collector/Grafana and define **3–5 platform KPIs**
  (render failure rate, validation failure categories, template usage, onboarding time, output-format
  usage). Use them to justify the Tier-3 freeze (A2) and template investment. *Best practice:*
  product metrics drive roadmap, not intuition.

**A12. Lower the KCL barrier.**
- Reproducible dev env (**devbox/Nix** or a pinned dev container) so `kcl`, `kubeconform`,
  `crossplane`, `helm` versions are one command. Expand `koncept doctor`/error hints for the top
  recurring KCL/module-resolution failures surfaced by A11. *Best practice:* paved-road local setup.

---

## 4. Priority matrix

| Priority | Action | Outcome |
|---|---|---|
| **P0** | A1 Doc consolidation + doc-lint CI | Repo becomes legible; no more competing "status" docs |
| **P0** | A2 Encode support tiers; freeze Tier-3 | Maintenance cost matches real demand |
| **P0** | A3 Execute OCI publish + pin one project | Versioned distribution proven, not just tooled |
| **P0** | A4 Real adoption pilot (non-author) | Usability claims validated by evidence |
| **P1** | A5 cosign/SLSA/SBOM on releases | Supply-chain integrity for multi-team consumption |
| **P1** | A6 Kyverno/OPA admission parity | Policy enforced at deploy time, not only render time |
| **P1** | A7 Renovate dependency automation | Pinned versions stay current and safe |
| **P1** | A8 Crossplane promotion gate | "Supported" APIs are actually proven |
| **P1** | A9 Converge bridge ↔ curated APIs | Removes last Crossplane duplication |
| **P2** | A10 Backstage golden paths live | Self-service for non-KCL users |
| **P2** | A11 Telemetry → KPIs | Roadmap driven by usage/pain |
| **P2** | A12 Reproducible dev env | Lowers KCL onboarding friction |

---

## 5. Guardrails (unchanged, still binding)

These principles from the evolution plan remain in force and constrain every action above:

- **No legacy, no compat shims, no two versions of the same thing.** Replace-and-delete in the same
  change. (Applies directly to A1: archive/delete, don't fork docs.)
- **No new Tier-1 output or template family** without a named internal consumer, tests, docs,
  ownership, and a lifecycle/deprecation plan.
- **Dry-run/CRD stubs are not production proof.** Promotion requires real reconciliation (A8).
- **Security is non-negotiable:** no secrets in code, no privileged containers, pinned versions,
  least-privilege RBAC, trusted-domain fetch only.

---

## 6. One-line summary

> idp-concept has won the **capability** battle; the next battle is **legibility, distribution, and
> proof**. Consolidate the docs, encode support tiers, actually publish and pin the framework, and
> prove the golden path with one independent team — before adding anything else.


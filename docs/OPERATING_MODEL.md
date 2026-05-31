# Operating Model

> Governance for **idp-concept** as a company-internal platform product. Defines
> who owns what, which changes need which approvals, and how the golden paths
> stay safe as several products adopt the platform.
>
> This expands Section 17 of the [IDP Evolution Plan](IDP_EVOLUTION_PLAN.md) into
> an actionable reference for day-to-day change management.

## Why an operating model

A medium company running several products on one platform needs a clear answer
to "who is allowed to change this, and who reviews it?" Without it, product teams
fork framework internals, policy drifts, and the platform becomes harder to run
than the problem it solves. The model below keeps **golden paths** safe while
still letting product teams move quickly inside their own projects.

## Roles

| Role | Owns | Typical work |
|---|---|---|
| **Application developers** | Site/tenant configuration for their services. | Use Backstage or `koncept`, configure approved inputs, review render diffs. |
| **Product platform champions** | `projects/<name>/` stacks and modules. | Add services from existing templates, request new templates, own product render output. |
| **Central platform team** | `framework/`, `cmd/koncept/`, templates, procedures, policy, CI, release process, docs. | Maintain golden paths, review framework changes, run releases. |
| **Security / operations reviewers** | Policy exceptions, runtime dependencies, production changes. | Approve `koncept policy check` exemptions, operator runtime adoption, production promotion. |

The intent is a layered ownership boundary that mirrors the code layout:
`framework/` (platform team) vs `projects/<name>/` (product team) vs
site/tenant config (developers).

## Change categories and approval paths

| Change | Who initiates | Approval path | Required gates |
|---|---|---|---|
| Site/tenant config change | Application developer | Normal app code review | `koncept validate`, `koncept policy check`, golden diff |
| New service from an existing template | Product platform champion | Product-team review of generated diff | `koncept init module`, render diff, policy check |
| New environment / release | Product platform champion | Product-team review | `koncept init env` / `init release`, render smoke |
| New framework template | Central platform team | Platform-team review | Tests + docs + acceptance fixture + changelog fragment |
| New output procedure | Central platform team | Platform-team architecture review | Support-tier decision + tests + docs |
| Policy exception | Any, sponsored by an owner | Security/operations reviewer | `--exemptions` waiver with owner, reason, expiry |
| Framework version bump consumed by a project | Product platform champion | Platform + product review | `koncept doctor`, golden + policy checks against pinned version |

## How the gates are enforced

Each change category maps to existing, automated checks so approval is grounded
in evidence rather than opinion:

- **`scripts/verify.sh`** — canonical KCL render + unit test gate (fast PR gate).
- **`koncept validate`** — factory configuration compiles.
- **`koncept policy check`** — baseline security/ownership rules; narrow, expiring
  `--exemptions` for reviewed exceptions (see [POLICY_EXEMPTIONS.md](POLICY_EXEMPTIONS.md)).
- **`koncept golden check`** / `scripts/golden.sh` — render drift is visible and
  intentionally approved (see [GOLDEN_OUTPUTS.md](GOLDEN_OUTPUTS.md)).
- **`koncept changelog check`** — framework release intent is reviewed with code
  (see [CHANGELOG_WORKFLOW.md](CHANGELOG_WORKFLOW.md)).
- **CI (`.github/workflows/validate.yml`)** — runs the above on every PR.
- **Runtime CI (`.github/workflows/runtime.yml`)** — opt-in/nightly real-cluster
  reconciliation for selected templates (see [ACCEPTANCE_RUNTIME.md](ACCEPTANCE_RUNTIME.md)).

## Self-service vs platform-owned

| Path | Self-service for developers/champions | Requires platform team |
|---|---|---|
| Configure an existing service | ✅ | |
| Add a service from a template | ✅ | |
| Add an environment or release | ✅ | |
| Add/modify a framework template or builder | | ✅ |
| Add/modify an output procedure | | ✅ |
| Change policy rules | | ✅ (+ security/ops for exceptions) |
| Cut a framework release / publish artifacts | | ✅ |

The rule of thumb: **product teams compose; the platform team extends the
framework.** Product teams should never need to fork `framework/` internals; if
they do, that is a signal to add an extension point or template upstream.

## Escalation and feedback

- Template or output gaps → open a request to the central platform team with a
  named consumer, so breadth is added only where it serves a real product need
  (see Phase H of the evolution plan).
- Repeated validation/policy failures → fold into the periodic platform review,
  using [PLATFORM_METRICS.md](PLATFORM_METRICS.md) aggregates to prioritize.
- Production incidents tied to a template → security/operations reviewers decide
  on runtime validation requirements before further rollout.

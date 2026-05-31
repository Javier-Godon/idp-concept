# Golden Output Workflow

Golden files are committed expected-render snapshots for reference projects. They
turn rendering changes into reviewable diffs: any framework or project change that
alters generated manifests fails the golden check until a human reviews and
accepts the new output. This is the platform's drift-review gate, complementing
typed validation (`koncept validate`) and the policy gate (`koncept policy check`).

## Why golden outputs

- **Reviewable drift**: A one-line framework change can ripple into many rendered
  manifests. Golden diffs make that blast radius visible in the PR.
- **Intentional change**: Updating a golden file is an explicit, reviewable act
  (`scripts/golden.sh update`), so accidental output changes do not merge silently.
- **Cheap and deterministic**: Renders run through the Go CLI with sorted keys
  (`WithSortKeys`), so snapshots are stable and comparisons are exact.

## Where golden files live

Each reference factory stores its snapshots next to the factory, under a sibling
`golden/<format>/manifests.yaml`:

```
projects/erp_back/
  pre_releases/manifests/dev/golden/yaml/manifests.yaml
  pre_releases/manifests/dev/golden/argocd/manifests.yaml
  pre_releases/manifests/stg/golden/yaml/manifests.yaml
  releases/v1_0_0_production/golden/yaml/manifests.yaml
```

The committed reference set (kept intentionally small and Tier-1 focused):

| Factory | Formats | What it guards |
|---|---|---|
| `erp_back` dev pre-release | `yaml`, `argocd` | The primary GitOps render path for a development environment. |
| `erp_back` stg pre-release | `yaml` | Profile/site layering differences for staging. |
| `erp_back` v1.0.0 production release | `yaml` | Immutable, version-pinned production render. |

`yaml`/`argocd` are the Tier-1 GitOps outputs and are the canonical drift guard.
Other formats (`helmfile`, `helm`, `backstage`, ...) are covered by the render
smoke checks in `scripts/verify.sh`; add them to golden coverage only when a real
consumer needs snapshot review for that format.

## Commands

```bash
# Check every reference factory against its committed snapshots (CI default).
./scripts/golden.sh check

# Re-render and overwrite snapshots after an intended change, then review the diff.
./scripts/golden.sh update
git diff -- projects/**/golden
```

Per-factory, the same is available directly on the CLI:

```bash
koncept --factory projects/erp_back/pre_releases/manifests/dev/factory golden check  --formats yaml,argocd
koncept --factory projects/erp_back/pre_releases/manifests/dev/factory golden update --formats yaml,argocd
```

On drift, `golden check` prints a concise line diff of the changed region
(`- ` golden vs `+ ` actual, with line numbers) so reviewers see exactly what
changed without opening the file.

## CI

The `Validate IDP` workflow (`.github/workflows/validate.yml`) runs
`./scripts/golden.sh check` in the Go CLI job, after the policy gate. A drift
fails the build with the diff in the logs.

## Updating goldens (reviewer checklist)

1. Make the framework/project change and run `./scripts/golden.sh update`.
2. Inspect `git diff -- projects/**/golden`. Confirm every changed line is
   intended (image tags, labels, resource shapes, ordering, new resources).
3. Commit the code change and the golden update together so the snapshot and the
   behaviour stay in lockstep.
4. If a diff is unexpected, treat it as a regression — fix the code, do not accept
   the golden.

## Adding a new reference factory

1. Add the `<factory-dir>|<formats>` entry to the `TARGETS` array in
   `scripts/golden.sh`.
2. Run `./scripts/golden.sh update` to generate the snapshot.
3. Commit the new `golden/` files. Keep the set small and representative —
   golden coverage is a review aid, not a substitute for unit/acceptance tests.

## Generated scaffold goldens

`scripts/golden.sh` guards *hand-authored* reference factories. A second gate,
`scripts/golden_generated.sh`, guards what the **Go CLI generates** — the golden
paths a new product team actually uses. It scaffolds each supported combination
with `koncept init project` plus `koncept init module --wire`, renders Tier-1
`yaml`, and diffs the result against a committed snapshot.

This catches regressions in three layers at once: the project/module scaffolding
templates, the marker-based stack wiring, and the framework templates those combos
consume.

Committed snapshots live under `tests/golden_generated/<combo>/manifests.yaml`:

| Combo | Scaffold steps | What it guards |
|---|---|---|
| `webapp` | `init project` | The minimal generated golden path (Deployment + Service + Namespace). |
| `webapp-postgres` | `init project` + `init module postgres --wire` | App + CloudNativePG `Cluster` accessory wiring. |
| `webapp-redis` | `init project` + `init module redis --wire` | App + Redis accessory wiring. |
| `webapp-kafka` | `init project` + `init module kafka --wire` | App + Strimzi `Kafka` accessory wiring. |

Only the rendered YAML is committed (one file per combo), never the whole
generated project tree, so the accept-the-diff burden stays proportional to value.

```bash
# Scaffold each combo into a temp workspace, render, and diff (CI default).
./scripts/golden_generated.sh check

# Re-render and overwrite snapshots after an intended scaffold/template change.
./scripts/golden_generated.sh update
git diff -- tests/golden_generated
```

The script mirrors the repo layout in a temp directory (symlinking `framework`)
so generated projects resolve the framework through the standard
`../../framework` path. Renders go through the same sorted-key CLI path as the
factory goldens, so they are byte-stable. CI runs the check in the Go CLI job,
right after `scripts/golden.sh check`.

To add a combo, append a `"<name>|<module-types>"` entry to the `COMBOS` array in
`scripts/golden_generated.sh` and run `update`. A module type must be supported by
`koncept init module` and the stack template must carry the koncept wire markers
(every `koncept init project` stack does).

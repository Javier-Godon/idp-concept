# koncept CLI Reference

> The `koncept` Go CLI is the supported user interface for idp-concept. KCL remains the source language and model layer, but day-to-day users should scaffold, validate, render, inspect, and govern projects through `koncept`.

## Command Model

Run commands from a project, pre-release, release, or factory directory. The CLI loads `koncept.yaml` and the nearest KCL module context, then uses the factory path from `--factory` or the default `factory`.

```bash
koncept [command] [flags]

Global flags:
  --factory <dir>       Factory directory, default: factory
  --output <dir>        Output directory override
  --metrics             Record opt-in local telemetry
  --metrics-file <path> Telemetry JSONL path override
```

Use `koncept doctor` first when a command cannot find the expected factory, `kcl.mod`, or output settings.

Install, update, uninstall, binary verification, and container image usage are
covered in [CLI_DISTRIBUTION.md](../operations/CLI_DISTRIBUTION.md). This page
focuses on command behavior after the CLI is available on `PATH`.

## Golden Path

```bash
# Create a complete project skeleton.
koncept init project "Inventory Service" \
  --owner platform-team \
  --git-repo https://github.com/example/inventory-service \
  --image ghcr.io/example/inventory-service \
  --version 1.0.0

# Render and validate the generated development environment.
koncept validate --factory projects/inventory_service/pre_releases/manifests/dev/factory
koncept dry-run --factory projects/inventory_service/pre_releases/manifests/dev/factory
koncept render argocd --factory projects/inventory_service/pre_releases/manifests/dev/factory
koncept policy check --factory projects/inventory_service/pre_releases/manifests/dev/factory
```

For an existing project, run from the project root and pass the factory path:

```bash
cd projects/erp_back
koncept validate --factory pre_releases/manifests/dev/factory
koncept render helmfile --factory pre_releases/manifests/dev/factory
koncept golden check --factory pre_releases/manifests/dev/factory --formats yaml,helmfile
```

For a release factory, run from the release directory:

```bash
cd projects/erp_back/releases/v1_0_0_production
koncept validate
koncept render argocd
```

## Render Formats

| Tier | Format | Command | Notes |
|---|---|---|---|
| Tier 1 | YAML | `koncept render yaml` | Plain Kubernetes YAML for GitOps or direct apply |
| Tier 1 | ArgoCD | `koncept render argocd` | Uses the YAML renderer for ArgoCD-ready GitOps output |
| Tier 1 | Helmfile | `koncept render helmfile` | Helm charts plus `helmfile.yaml` orchestration |
| Tier 1 | Backstage | `koncept render backstage` | Backstage catalog entity output |
| Tier 2 | Helm | `koncept render helm` | Standalone Helm chart structure |
| Tier 2 | Crossplane | `koncept render crossplane` | Generated Crossplane output for platform teams |
| Tier 2 | Kustomize | `koncept render kustomize` | Kustomize base output |
| Tier 3 | Kusion | `koncept render kusion` | Experimental compatibility output |
| Tier 3 | Timoni | `koncept render timoni` | Experimental CUE/Timoni output |

Tier 1 is the supported default for product teams. Tier 2 is maintained for platform and infrastructure use. Tier 3 is experimental and should be gated by an explicit adoption decision.

## Scaffolding Commands

### `koncept init project`

Creates a complete project under `projects/<slug>/` with kernel, core sources, modules, stacks, tenant/site config, and a development factory.

```bash
koncept init project "Orders API" \
  --owner payments-team \
  --git-repo https://github.com/example/orders-api \
  --image ghcr.io/example/orders-api \
  --version 1.2.3 \
  --port 8080
```

Useful flags:

| Flag | Purpose |
|---|---|
| `--dest` | Destination root, default `projects` |
| `--framework-path` | Relative path to the framework package from the project root |
| `--owner` | Ownership or Backstage owner value |
| `--git-repo` | Project repository URL |
| `--image` / `--version` | Application image and pinned tag |
| `--port` | Application service/container port |
| `--validate` | Validate after generation, default `true` |

### `koncept init module`

Adds a module definition under `modules/<area>/<name>/<name>_module_def.k`. Supported types are `webapp`, `database`, `postgres`, `redis`, `kafka`, `mongodb`, and `rabbitmq`.

```bash
koncept init module webapp orders-api --image ghcr.io/example/orders-api --version 1.2.3
koncept init module postgres orders-db --storage 20Gi
koncept init module redis orders-cache --wire
```

Use `--wire` only when the target stack contains the marker block expected by the CLI. Without markers, the command prints a paste-ready stack snippet and leaves stack wiring to the platform engineer.

### `koncept init env`

Adds a new environment to an existing project by generating the profile, site, and pre-release factory.

```bash
koncept init env staging --namespace orders-stg-apps --storage-class local-path
koncept init env prod --storage-class rook-ceph-block
```

### `koncept init release`

Creates an immutable versioned release factory under `releases/<version>_production/factory`.

```bash
koncept init release 1.0.0 --storage-class rook-ceph-block
```

## Validation And Planning

| Command | Use |
|---|---|
| `koncept validate` | Compile the factory seed and catch KCL/configuration errors before rendering |
| `koncept dry-run` | Preview merged configuration, module dependency edges, Helmfile projection, and Crossplane sequencing metadata |
| `koncept doctor` | Check factory files, nearest `kcl.mod`, KCL availability, output settings, and common path problems |
| `koncept deps` | Show dependency files for a KCL package when module resolution is confusing |
| `koncept diff [format]` | Render and compare against existing output |

A normal pre-render loop is:

```bash
koncept doctor --factory <factory>
koncept validate --factory <factory>
koncept dry-run --factory <factory>
koncept render argocd --factory <factory>
```

## Governance Commands

| Command | Use |
|---|---|
| `koncept policy check` | Enforce baseline security and ownership rules on rendered YAML/ArgoCD output |
| `koncept golden check` | Detect drift against committed golden snapshots |
| `koncept golden update` | Intentionally refresh golden snapshots after review |
| `koncept changelog check` | Validate release-note fragments under `.changes/unreleased` |
| `koncept metrics` | Summarize opt-in local CLI telemetry |

`koncept policy check` verifies no privileged containers, no unpinned images, resources on Tier-1 workloads, ownership labels, secret references for secret-looking env values, explicit namespaces, and namespace-level NetworkPolicies. Prefer narrow expiring waivers through `--exemptions` over disabling rules globally.

## KCL Maintenance Commands

| Command | Use |
|---|---|
| `koncept fmt` | Format KCL files |
| `koncept lint` | Lint KCL files for common issues |
| `koncept test` | Run KCL tests |
| `koncept publish` | Publish a KCL module as an OCI artifact |

Direct `kcl run` remains useful for framework debugging, but project users should prefer the CLI because it captures repository conventions and output routing.

## Version And Health Checks

```bash
koncept --version
koncept doctor --factory <factory>
```

There is no `koncept version` subcommand and no `koncept version --kcl` flag.
Use `koncept --version` for the CLI build and `koncept doctor` to report the KCL
CLI found on the host or in the container image.

## Crossplane Commands

`koncept crossplane test` validates generated Crossplane v2 output contracts and can run local render/runtime profiles. Use it for the generated Crossplane output path. Hand-authored APIs under `crossplane_v2/` follow the curated Crossplane architecture described in [CROSSPLANE_PATTERNS.md](../integrations/CROSSPLANE_PATTERNS.md) and the Crossplane architecture instructions.

## Troubleshooting

| Symptom | First command | Likely fix |
|---|---|---|
| `render.k not found` | `koncept doctor --factory <factory>` | Run from the release/pre-release directory or pass `--factory` |
| `cannot find module` | `koncept deps` | Fix the nearest `kcl.mod` or run from the expected module root |
| Render succeeds but output changed | `koncept diff <format>` | Review intentional changes, then update golden files if needed |
| Policy warnings are noisy | `koncept policy check --exemptions policy-exemptions.yaml` | Add owned, expiring waivers for narrow cases |
| Tier 3 output warning appears | `koncept render yaml` or `koncept render helmfile` | Prefer Tier 1 unless the experiment is explicitly approved |

## Related Docs

- [DEVELOPER_QUICKSTART.md](DEVELOPER_QUICKSTART.md) for the shortest path to first render.
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) for how the CLI maps onto the project architecture.
- [WORKFLOWS.md](WORKFLOWS.md) for role-based recipes.
- [TOOLING_SETUP.md](../operations/TOOLING_SETUP.md) for installation.
- [GOLDEN_OUTPUTS.md](../testing/GOLDEN_OUTPUTS.md), [POLICY_EXEMPTIONS.md](../operations/POLICY_EXEMPTIONS.md), and [CHANGELOG_WORKFLOW.md](../operations/CHANGELOG_WORKFLOW.md) for governance details.

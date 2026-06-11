# Windows Local Setup and Company Laptop Guidance

This project can be developed from Windows, but the most reliable local Kubernetes path is **WSL2 + Docker Desktop + kind**. Use lightweight `footprint = "local"` template settings for laptop environments.

Install, update, and uninstall `koncept` from inside WSL2 using
[CLI_DISTRIBUTION.md](../operations/CLI_DISTRIBUTION.md). Install supporting
tools with [TOOLING_SETUP.md](../operations/TOOLING_SETUP.md).

## Recommended stack

1. Windows 11 with WSL2 enabled.
2. Ubuntu on WSL2.
3. Docker Desktop using the WSL2 backend.
4. Tooling installed inside WSL2: `git`, `kcl`, `kubectl`, `kind`, `helm`, and optionally `go-task`.

Run project commands from the WSL filesystem, not from `/mnt/c/...`, to avoid slow file I/O and path edge cases.

```bash
cd ~/workspaces/idp-concept
koncept doctor --factory projects/erp_back/pre_releases/manifests/dev/factory
./scripts/verify.sh
./scripts/acceptance_kind.sh --case basic
```

## Local footprint policy

Production templates intentionally default to stricter settings: multiple replicas, persistent volumes, production storage classes, and operator-backed resources. For local, development, or staging environments, select a lighter footprint where supported:

```kcl
schema DevPostgres(pg.PostgreSQLClusterModule):
    footprint = "local"
    clusterName = "dev-pg"
```

Footprints:

| Footprint | Use case |
|---|---|
| `local` | kind/minikube/company laptop, lowest resource usage |
| `development` | shared dev with low cost |
| `staging` | production-like but smaller |
| `production` | default production posture |

## Ceph on Windows / local laptops

Rook Ceph is usually a poor fit for corporate Windows laptops and nested local clusters:

- it needs Linux kernel/storage behavior that Docker Desktop + WSL2 may not expose cleanly;
- it can require extra disks, loop devices, privileged operations, and more memory;
- corporate endpoint protection can block low-level disk/container behavior;
- it is resource-intensive for a single-node local cluster.

Recommended alternatives:

1. For template validation, run dry-run only:

```bash
./scripts/acceptance_kind.sh --case ceph
./scripts/acceptance_kind.sh --case persistence-ceph
```

1. For functional local persistence, use kind's default local-path provisioner and `footprint = "local"`.
2. For real Ceph validation, use a Linux workstation, remote dev cluster, or CI/nightly cluster with dedicated storage.
3. Do not force Ceph storage classes into local templates unless the scenario is explicitly testing Ceph wiring.

## Operators and Helm-backed templates

Many templates render CRDs or HelmRelease resources. Server-side dry-run verifies shape, but real reconciliation requires the matching controller/operator.

Use:

```bash
./scripts/acceptance_kind.sh --case templates
```

For real runtime tests, use:

```bash
./scripts/acceptance_runtime.sh --case runtime-basic
```

Only run heavier runtime groups when the required dependencies are installed or when the script supports installing pinned dependencies.

## Windows troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Slow `kcl test` or `git` | Running under `/mnt/c` | Clone into WSL filesystem (`~/workspaces/...`) |
| Docker/kind cannot start | Docker Desktop WSL integration disabled | Enable Docker Desktop → Settings → Resources → WSL Integration |
| PVCs stay Pending | No StorageClass/provisioner | Use kind default local-path, or select `footprint = "local"` |
| Ceph pods fail or never become Ready | Nested local storage limitations | Use dry-run locally; validate Ceph on Linux/remote cluster |
| File permission issues | Mixed Windows/WSL checkout | Keep repo and generated files inside WSL |

## Minimal verification commands

```bash
cd ~/workspaces/idp-concept
./scripts/verify.sh
./scripts/acceptance_kind.sh --case basic
./scripts/acceptance_kind.sh --case data-admin
./scripts/acceptance_kind.sh --case release-notes
```

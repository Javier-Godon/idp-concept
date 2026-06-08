# Platform Installation Guide

> This guide explains what it means to install idp-concept. The platform is not one monolithic service: it is a CLI, a KCL framework, project definitions, optional developer-portal assets, optional Crossplane APIs, and GitOps-rendered output.

## What Gets Installed

| Layer | Required | Installed where | Purpose |
|---|---|---|---|
| `koncept` CLI | Yes | Developer machines, CI runners, Backstage backend runtime | Scaffold, validate, render, govern, and troubleshoot |
| KCL toolchain | Yes for local source builds; bundled in CI/container paths | Developer machines and CI images | Compile and render KCL source |
| Framework KCL package | Yes | This repo, or published OCI/module package when adopted | Shared schemas, templates, builders, and render procedures |
| Project definitions | Yes | Git repository under `projects/` or a consumer repo | Product-specific source of truth |
| GitOps output | Usually | ArgoCD/Flux/Helmfile deployment repository | Deploy rendered manifests/charts |
| Backstage assets | Optional but recommended | Existing or new Backstage instance | Self-service portal, catalog, scaffolder templates |
| Crossplane v2 APIs | Optional platform layer | Kubernetes cluster with Crossplane installed | Typed infrastructure self-service APIs |

## Installation Order

1. Install local and CI tooling.
2. Build or download the `koncept` CLI.
3. Validate a reference project.
4. Choose the default deployment output (`yaml`/`argocd` or `helmfile`).
5. Optionally install Backstage for self-service workflows.
6. Optionally install Crossplane v2 APIs for infrastructure control-plane workflows.

## 1. Install Local Tooling

Follow [../operations/TOOLING_SETUP.md](../operations/TOOLING_SETUP.md) for developer workstations and CI runners.

Minimum local path:

```bash
cd cmd/koncept
make build
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/koncept" ~/.local/bin/koncept
koncept --help
```

For distribution through releases, checksums, and the container image, follow [../operations/CLI_DISTRIBUTION.md](../operations/CLI_DISTRIBUTION.md).

## 2. Validate The Platform Baseline

Run the CLI against the maintained reference project before onboarding a real team:

```bash
cd projects/erp_back
koncept doctor --factory pre_releases/manifests/dev/factory
koncept validate --factory pre_releases/manifests/dev/factory
koncept dry-run --factory pre_releases/manifests/dev/factory
koncept render argocd --factory pre_releases/manifests/dev/factory
koncept policy check --factory pre_releases/manifests/dev/factory
```

Run the broader verification suite when changing framework code:

```bash
./scripts/verify.sh
```

## 3. Install A Consumer Project

For a new project, use the CLI scaffold:

```bash
koncept init project "Orders API" \
  --owner payments-team \
  --git-repo https://github.com/example/orders-api \
  --image ghcr.io/example/orders-api \
  --version 1.0.0

koncept validate --factory projects/orders_api/pre_releases/manifests/dev/factory
koncept render argocd --factory projects/orders_api/pre_releases/manifests/dev/factory
```

For an existing project, keep the project source in Git and require these checks before merging environment or stack changes:

```bash
koncept validate --factory <factory>
koncept dry-run --factory <factory>
koncept policy check --factory <factory>
koncept golden check --factory <factory> --formats yaml,helmfile
```

## 4. Install The Deployment Path

Choose one default delivery path per team.

### ArgoCD / Plain YAML

```bash
koncept render argocd --factory <factory> --output output
```

Commit or publish the rendered manifests to the GitOps location watched by ArgoCD or Flux. Do not hand-edit rendered output; change KCL source and re-render.

### Helmfile

```bash
koncept render helmfile --factory <factory> --output output
```

This produces chart output plus `helmfile.yaml`. Use this path for Helm-native teams that already operate Helmfile release orchestration.

## 5. Install Backstage Self-Service

Backstage is optional, but it is the preferred interface for users who should not edit KCL directly. This repository provides Backstage assets under `backstage/`; it does not replace an organization's Backstage app lifecycle.

### Backstage Prerequisites

- An existing Backstage app, or a new Backstage app created from the official Backstage project template and committed with a lockfile.
- `koncept` available on the Backstage backend runtime `PATH`.
- Network access from the backend runtime to the project Git provider.
- Kubernetes access only if using the Kubernetes, ArgoCD, Crossplane, or ingestor plugins.
- Secrets supplied through environment variables or the organization's secret manager. Do not put tokens in template YAML or app config.

### Register The idp-concept Assets

Copy or package these assets into the Backstage app:

| Repo path | Backstage destination | Purpose |
|---|---|---|
| `backstage/catalog-info.yaml` | Catalog location | Catalog metadata for the platform assets |
| `backstage/plugins/koncept-actions/` | Backend plugin workspace/package | Custom scaffolder actions that call `koncept` |
| `backstage/templates/*.yaml` | Catalog template locations | Self-service templates for apps, infrastructure, releases, and deployments |

Register template locations in the Backstage app configuration:

```yaml
catalog:
  locations:
    - type: file
      target: ../../backstage/catalog-info.yaml
      rules:
        - allow: [Component, System, Domain, Resource, Template]
    - type: file
      target: ../../backstage/templates/new-web-application.yaml
      rules:
        - allow: [Template]
    - type: file
      target: ../../backstage/templates/new-postgresql-database.yaml
      rules:
        - allow: [Template]
    - type: file
      target: ../../backstage/templates/new-release.yaml
      rules:
        - allow: [Template]
```

Register additional template YAML files from `backstage/templates/` as needed.

### Install Backstage Plugins

Use [../integrations/BACKSTAGE_PLUGIN_GUIDE.md](../integrations/BACKSTAGE_PLUGIN_GUIDE.md) for plugin-specific setup:

- Kubernetes plugin for workload visibility.
- TeraSky Kubernetes Ingestor for catalog discovery from Kubernetes resources.
- Crossplane resources plugin for XR/managed-resource graph visibility.
- Argo CD plugin for sync and health status.
- Keycloak authentication and RBAC.
- TechDocs and observability plugins.

### Deploy Backstage With The Framework Template

For platform-owned Backstage instances, model Backstage itself with the framework template instead of keeping it as an external snowflake.

```kcl
import framework.templates.backstage.v1_0_0.backstage as bs
import framework.templates.postgresql.v1_0_0.postgresql as pg

_pg_spec = pg.CNPGClusterSpec {
    name = "backstage-db"
    namespace = "backstage"
    instances = 2
    storageSize = "10Gi"
}

_bs_spec = bs.BackstageHelmSpec {
    name = "backstage"
    namespace = "backstage"
    host = "backstage.example.com"
    postgresHost = "backstage-db-rw.backstage.svc"
    postgresSecretName = "backstage-db-app"
    cpuRequest = "500m"
    memoryRequest = "1Gi"
}
```

Required cluster services:

- Ingress controller.
- CloudNativePG operator for the PostgreSQL backing database.
- cert-manager for TLS, when exposed publicly.
- Keycloak, when using the documented auth path.

Render and deploy through the same GitOps path as any other platform component:

```bash
koncept validate --factory <backstage-factory>
koncept render helmfile --factory <backstage-factory> --output output
koncept policy check --factory <backstage-factory>
```

Review the output before applying it to a cluster.

## 6. Install Crossplane Platform APIs

Crossplane is optional and belongs to platform engineering, not ordinary application developers. Use it for curated infrastructure APIs such as databases, queues, object storage, identity, certificates, storage, and secrets.

High-level sequence:

1. Install Crossplane in the target cluster using the organization's approved method.
2. Review and apply pinned providers from `crossplane_v2/providers/`.
3. Review and apply pinned functions from `crossplane_v2/functions/`.
4. Review and apply selected APIs from `crossplane_v2/managed_resources/<service>/`.
5. Validate with `koncept crossplane test` and the runbooks in [../testing/CROSSPLANE_TESTING_GUIDE.md](../testing/CROSSPLANE_TESTING_GUIDE.md) and [../operations/E2_OPERATING_RUNBOOK.md](../operations/E2_OPERATING_RUNBOOK.md).

Example review commands:

```bash
find crossplane_v2/providers crossplane_v2/functions -type f -name '*.yaml' | sort
find crossplane_v2/managed_resources/postgres -type f -name '*.yaml' | sort
```

Apply only after review:

```bash
kubectl apply -f crossplane_v2/providers/kubernetes_provider/provider_kubernetes_install.yaml
kubectl apply -f crossplane_v2/providers/helm_provider/provider_kubernetes_install.yaml
kubectl apply -f crossplane_v2/functions/
kubectl apply -f crossplane_v2/managed_resources/postgres/
```

The curated hand-authored `crossplane_v2/` APIs are separate from generated `koncept render crossplane` output. Do not turn every application workload into a Crossplane API. Follow [../integrations/CROSSPLANE_PATTERNS.md](../integrations/CROSSPLANE_PATTERNS.md).

## 7. Production Readiness Checklist

- `koncept` binary or container image is pinned and verified.
- KCL version is pinned for CI and local development.
- Default render path is chosen and documented for the team.
- CI runs `koncept validate`, `koncept policy check`, and golden checks for supported outputs.
- Backstage backend runtime has `koncept` on `PATH` before enabling scaffolder actions.
- Backstage templates are registered from version-controlled files.
- Secrets are supplied by environment variables or secret managers, not by committed YAML.
- Crossplane providers, functions, and managed-resource APIs are reviewed before apply.
- Runtime acceptance tests are scheduled or manually runnable for real cluster dependencies.

## Related Docs

- [../developer/README.md](../developer/README.md) for developer-facing workflows.
- [../operations/README.md](../operations/README.md) for CLI distribution, security, publishing, and governance.
- [../integrations/BACKSTAGE_PLUGIN_GUIDE.md](../integrations/BACKSTAGE_PLUGIN_GUIDE.md) for Backstage plugin details.
- [../integrations/CROSSPLANE_PATTERNS.md](../integrations/CROSSPLANE_PATTERNS.md) for Crossplane architecture and patterns.
- [../testing/README.md](../testing/README.md) for verification and acceptance testing.

# Project Folder Standard

This convention keeps KCL files small and lets both `koncept` and KCL helpers derive common values from paths instead of repeating them in every `profile_def.k`, `tenant_def.k`, `site_def.k`, or `factory_seed.k`.

KCL helpers live in `framework/factory/conventions.k`. They are intentionally small and only derive metadata from paths; KCL imports remain explicit because import paths are compile-time values.

## Project root

```text
projects/<project_slug>/
  kcl.mod
  kernel/
  core_sources/
  modules/
  stacks/
  tenants/
  sites/
  pre_releases/
  releases/
```

Derived values:

| Value | Source |
|---|---|
| `koncept_project_slug` | `<project_slug>` folder name |
| `koncept_project_version` | `[package].version` in `projects/<project_slug>/kcl.mod` |

## Stack folders

```text
projects/<project_slug>/stacks/development/
  profile_configurations.k
  profile_def.k        # exports `profile`
  stack_def.k          # exports `schema Stack`

projects/<project_slug>/stacks/versioned/v<major>_<minor>_<patch>/
  profile_configurations.k
  profile_def.k        # exports `profile`
  stack_def.k          # exports `schema Stack`
```

Recommended exports:

- `profile_def.k` exports `profile`.
- `stack_def.k` exports `schema Stack`.
- Historical project-specific names can remain as aliases for compatibility.
- Shared module wiring should live in a project-level stack template such as `stacks/erp_back_stack.k`; stack folders should only override versions or behavior that actually changes.

Minimal profile pattern:

```kcl
import file
import framework.factory.conventions as conventions
import my_project.core_sources.my_configurations
import my_project.stacks.versioned.v1_0_0.profile_configurations

profile = conventions.build_profile(conventions.ProfileSpec {
    currentFile = file.current()
    configurations = my_configurations.MyConfigurations {
        **profile_configurations._profile_configurations
    }
})
```

Derived `profile.name` examples:

| Folder | Derived name |
|---|---|
| `stacks/development/` | `development` |
| `stacks/versioned/v1_0_0/` | `v1_0_0` |

## Tenants

```text
projects/<project_slug>/tenants/<tenant_slug>/tenant_def.k
```

Recommended export:

- `tenant_def.k` exports `tenant`.

Minimal tenant pattern:

```kcl
import file
import framework.factory.conventions as conventions
import my_project.core_sources.my_configurations

tenant = conventions.build_tenant(conventions.TenantSpec {
    currentFile = file.current()
    # Optional. Defaults to a title-cased folder name, e.g. `acme_corp` → `Acme Corp`.
    name = "ACME Corp"
    description = "Enterprise customer"
    configurations = my_configurations.MyConfigurations {
        brandIcon = "acme-logo"
    }
})
```

## Sites

```text
projects/<project_slug>/sites/<environment>/<site_slug>/
  configurations.k
  site_def.k           # exports `site`
```

Recommended export:

- `site_def.k` exports `site`.
- `configurations.k` can set `siteName` to the externally meaningful site name when it differs from the derived value.
- A `default` site folder derives the environment name as the site name; for example `sites/production/default` derives `production`.

Minimal site pattern:

```kcl
import file
import framework.factory.conventions as conventions
import my_project.core_sources.my_configurations
import my_project.sites.production.default.configurations
import my_project.tenants.acme_corp.tenant_def

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = my_configurations.MyConfigurations {
        **configurations._site_configurations
    }
})
```

## Pre-release factories

```text
projects/<project_slug>/pre_releases/manifests/<env>/factory/
  factory_seed.k
  render.k
```

Derived values:

| KCL option | Example for `projects/erp_back/pre_releases/manifests/dev/factory` |
|---|---|
| `koncept_release_kind` | `pre_release` |
| `koncept_release_id` | `dev` |
| `koncept_environment` | `dev` |
| `koncept_version` | `<kcl.mod version>-dev`, e.g. `0.0.1-dev` |
| `koncept_release_name` | `pre_release_dev` |
| `koncept_manifest_path` | `projects/erp_back/pre_releases/manifests/dev/output` |

## Release factories

```text
projects/<project_slug>/releases/v<major>_<minor>_<patch>_<environment>/factory/
  factory_seed.k
  render.k
```

Derived values:

| KCL option | Example for `projects/erp_back/releases/v1_0_0_production/factory` |
|---|---|
| `koncept_release_kind` | `release` |
| `koncept_release_id` | `v1_0_0_production` |
| `koncept_environment` | `production` |
| `koncept_version` | `1.0.0` |
| `koncept_release_name` | `release_v1_0_0_production` |
| `koncept_manifest_path` | `projects/erp_back/releases/v1_0_0_production/output` |

## Minimal factory seed pattern

With the standard folder layout, `factory_seed.k` only needs static imports and the selected project/profile/tenant/site/stack. Use `conventions.context_from_path(file.current())` for release values, then pass the stack schema directly to `FactorySeed`.

Do not wrap `FactorySeed` behind a generic lambda that accepts `stackSchema: any`; direct schema passing is more reliable with KCL schema instantiation.

```kcl
import file
import framework.factory.conventions as conventions
import framework.factory.seed as seed
import my_project.stacks.versioned.v1_0_0.stack_def
import my_project.stacks.versioned.v1_0_0.profile_def
import my_project.tenants.acme.tenant_def
import my_project.sites.production.default.site_def
import my_project.kernel.project_def

_context = conventions.context_from_path(file.current())

_factory = seed.FactorySeed {
    project = project_def.project
    profile = profile_def.profile
    tenant = tenant_def.tenant
    site = site_def.site
    stackSchema = stack_def.Stack
    version = _context.version
    releaseName = _context.releaseName
    manifestPath = _context.manifestPath
}

_stack = _factory.renderStack
_project_name = _factory.projectName
_git_repo_url = _factory.gitRepoUrl
_manifest_path = _factory.manifestPath
```

## KCL helper reference

| Helper | Purpose |
|---|---|
| `project_slug_from_path(file.current())` | Derives `<project_slug>` from `projects/<project_slug>/...` |
| `project_root_from_path(file.current())` | Derives the local project root path |
| `project_version_from_path(file.current())` | Reads `[package].version` from the project's `kcl.mod` when available |
| `profile_name_from_path(file.current())` | Derives `development` or `v1_0_0` from stack folders |
| `tenant_id_from_path(file.current())` | Derives `<tenant_slug>` from tenant folders |
| `site_name_from_path(file.current())` | Derives `<site_slug>` or environment for `default` site folders |
| `context_from_path(file.current())` | Derives release kind, ID, environment, version, release name, and manifest path |
| `build_profile(ProfileSpec)` | Creates a framework `Profile` with the derived name |
| `build_tenant(TenantSpec)` | Creates a framework `Tenant` with optional display-name override |
| `build_site(SiteSpec)` | Creates a framework `Site` with the derived name |

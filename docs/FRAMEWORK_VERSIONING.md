# Framework Versioning and Compatibility

This document defines the first framework compatibility contract for projects that consume `framework/`.

## Current state

`framework/` is still consumed from a local path in this repository for most examples. The platform is not yet publishing versioned KCL or OCI artifacts, so compatibility metadata is **descriptive** today: it makes project intent visible to reviewers and CLI diagnostics without blocking existing stacks.

New generated projects now include:

- `koncept.yaml` project metadata under `spec.framework`,
- stack-level `compatibility = compat.FrameworkCompatibility { ... }`,
- `koncept doctor` output for framework source, version, version constraint, support tier, and tested versions.

## Versioning rules

Use semantic versioning for the framework once distribution is published:

| Change | Version impact | Examples |
|---|---|---|
| Patch | `x.y.Z` | Bug fixes, docs, non-behavioral CLI diagnostics, new optional fields with safe defaults. |
| Minor | `x.Y.z` | New templates, new render options, new policy warnings, compatible schema additions. |
| Major | `X.y.z` | Removed fields, renamed imports, changed render contracts, policy failures replacing warnings. |

Until the first tagged framework release, generated projects use `version: dev` with `versionConstraint: ">=0.1.0 <1.0.0"` to document intent without pretending a remote artifact exists.

## Project metadata contract

`koncept.yaml` should declare the framework source and compatibility expectation:

```yaml
apiVersion: koncept.bluesolution.es/v1
kind: ProjectConfig
spec:
  frameworkPath: "../../framework"
  framework:
    source: local
    version: dev
    versionConstraint: ">=0.1.0 <1.0.0"
    supportTier: tier-1
    supportWindow: "until next minor framework release"
    testedVersions:
      - dev
```

Stacks and releases can carry the same intent in KCL:

```kcl
import framework.models.compatibility as compat

compatibility = compat.FrameworkCompatibility {
    version = "dev"
    versionConstraint = ">=0.1.0 <1.0.0"
    supportTier = "tier-1"
    source = "local"
}
```

## Support tiers and windows

| Tier | Meaning | Support window |
|---|---|---|
| `tier-1` | Default golden path outputs/templates used by product teams. | Supported through at least the next minor framework release. |
| `tier-2` | Platform-team or infrastructure-oriented paths. | Best-effort compatibility; migrations documented when behavior changes. |
| `experimental` | Incubating outputs/templates with no production consumer yet. | May change between minor releases; do not use for critical products without platform approval. |
| `deprecated` | Replaced functionality kept for transition. | Must declare a removal target and migration guide before removal. |

## Deprecation policy

1. Mark the stack/template/output as deprecated in docs and compatibility metadata.
2. Add a changelog fragment explaining the replacement and owner.
3. Keep a migration path for at least one minor release for `tier-1` consumers.
4. Convert warnings to failures only in a major release or after the documented support window.

## Migration path to remote distribution

When framework publishing is ready, projects should move in stages:

1. Keep the local `frameworkPath` and add compatibility metadata.
2. Tag a framework release and update `testedVersions`.
3. Switch one reference project to the tagged module/artifact.
4. Extend CI to run `koncept doctor`, golden checks, and policy checks against the pinned version.
5. Migrate product projects one by one instead of changing every project at once.


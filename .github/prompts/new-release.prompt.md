---
description: Create a new versioned release or pre-release with factory builders
---

# Create a New Release

You are creating a new versioned release for a specific site in idp-concept.

## Context Files
- #file:docs/AI_REFERENCE.md
- #file:.github/instructions/kcl-module-system.instructions.md
- #file:projects/erp_back/pre_releases/gitops/dev/factory/factory_seed.k
- #file:projects/erp_back/pre_releases/gitops/dev/factory/yaml_builder.k
- #file:projects/erp_back/pre_releases/kcl.mod
- #file:projects/video_streaming/releases/helmfile/berlin/v1_0_0_berlin/factory/factory_seed.k
- #file:projects/video_streaming/releases/helmfile/berlin/v1_0_0_berlin/factory/chart_builder.k

## Rules
1. **Pre-releases** go under `pre_releases/gitops/<site>/factory/`
2. **Releases** go under `releases/<format>/<site>/<version>/factory/`
3. Format is one of: `helmfile`, `kusion`, `gitops`
4. Create a `factory/` directory with:
   - `factory_seed.k` — Imports project, tenant, site, profile, merges configs, creates stack + GitOpsStack
   - Format-specific builders
5. For gitops/yaml: need `yaml_builder.k`
6. For helmfile: need chart_builder.k + templates_builder.k + helmfile_builder.k + values_builder.k
7. For kusion: need main.k that creates Release with kusionSpec
8. The factory_seed.k MUST merge configurations in order: kernel → profile → tenant → site
9. **CRITICAL**: `pre_releases/kcl.mod` MUST depend ONLY on the parent project (NOT framework directly). Framework resolves transitively.
10. Use relative imports (`import .factory_seed`) within the factory directory

## Ask the user
- Pre-release or release?
- Target site (e.g., dev, berlin, paris)
- Output format (gitops/yaml, helmfile, kusion)
- Which stack version to use
- Which tenant and site to reference

---
name: knowledge-research
description: "Research niche technologies (KCL, Nushell, Crossplane, Kusion, IDP patterns) using authoritative sources. Use when the AI lacks training data on a topic, needs to verify its own knowledge against official docs, or must learn a new pattern before generating code."
---

# Knowledge Research Skill for idp-concept

## When to Use
- Before writing KCL code — verify syntax against official docs
- Before creating Crossplane compositions — check function-kcl API
- Before modifying Nushell scripts — verify command syntax
- When the user asks about a technology the AI has limited training data on
- When implementing a pattern the AI hasn't seen before
- When the AI needs to validate its own knowledge (KCL, Kusion, platform engineering)

## Critical Principle

**This project uses niche technologies where AI training data is limited and unreliable.** The project creator is a practitioner, not a KCL/IDP expert. The code in `framework/` and `projects/` represents functional working solutions, but they may not follow best practices from the official ecosystems.

**Always cross-reference with authoritative sources before generating code.**

## Authoritative Source Priority

| Priority | Source | Trust Level | How to Access |
|---|---|---|---|
| 1st | Official docs (kcl-lang.io, nushell.sh, docs.crossplane.io) | **Authoritative** | Fetch via MCP |
| 2nd | Official repos (kcl-lang/*, crossplane-contrib/function-kcl) | **Authoritative** | Fetch raw GitHub content |
| 3rd | Expert practitioner repos (vfarcic/crossplane-kubernetes) | **High** | Fetch raw GitHub content |
| 4th | Local project code (`framework/`, `projects/`) | **Functional but not authoritative** | Read local files |
| 5th | AI training data | **Unreliable for niche tech** | Use only as last resort, ALWAYS verify |

## Research Workflows

### KCL Syntax Verification

When unsure about KCL syntax, schema inheritance, or built-in functions:

1. **First check** the local skill: `.github/skills/kcl-language/SKILL.md`
2. **Then fetch** official docs:
   - Language spec: `https://www.kcl-lang.io/docs/reference/lang/spec/`
   - Schema spec: `https://www.kcl-lang.io/docs/reference/lang/spec/schema`
   - Built-in functions: `https://www.kcl-lang.io/docs/reference/model/overview`
   - Standard library: `https://www.kcl-lang.io/docs/reference/model/`
3. **For module system**: Check `.github/instructions/kcl-module-system.instructions.md`
4. **For real-world patterns**: Fetch `https://github.com/kcl-lang/examples`
5. **For schema design**: Fetch `https://github.com/kcl-lang/konfig`

### Crossplane + KCL Composition

When creating or modifying Crossplane compositions with KCL:

1. **Check function-kcl API**:
   - Fetch `https://github.com/crossplane-contrib/function-kcl` README
   - Key API: `option("params").oxr`, `.ocds`, `.dxr`, `.dcds`, `.ctx`
   - Source modes: inline, OCI, Git, filesystem
2. **Reference working examples**:
   - Fetch `https://raw.githubusercontent.com/vfarcic/crossplane-kubernetes/main/CLAUDE.md`
   - Fetch KCL files from `https://github.com/vfarcic/crossplane-kubernetes/tree/main/kcl`
3. **Local reference**: `crossplane_v2/` directory in this project

### Nushell Script Patterns

When modifying `platform_cli/koncept` or `platform_cli/koncepttask`:

1. **Fetch command reference**: `https://www.nushell.sh/commands/`
2. **Fetch language guide**: `https://www.nushell.sh/book/`
3. **For advanced patterns**: Fetch from `https://github.com/vfarcic/crossplane-app` (78.7% Nushell)
4. **For Nushell + AI integration**: Fetch from `https://github.com/vfarcic/dot-ai`

### Kusion Spec Format

When working with `kcl_to_kusion` procedure:

1. **Fetch Kusion docs**: `https://www.kusionstack.io/docs/`
2. **Check KusionStack/kusion repo**: `https://github.com/KusionStack/kusion`
3. **Local reference**: `framework/procedures/kcl_to_kusion.k`

### Platform Engineering Concepts

When making architectural decisions or validating IDP patterns:

1. **CNCF Maturity Model**: `https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model`
2. **CNCF Platforms Whitepaper**: `https://tag-app-delivery.cncf.io/whitepapers/platforms/`
3. **Kratix Promises pattern**: `https://docs.kratix.io/` (parallels Stack/Module)
4. **Score workload spec**: `https://score.dev/docs/` (developer intent → platform implementation)

### Helm/Helmfile Alternatives

When evaluating or implementing alternative output formats:

1. **Timoni** (CUE-powered): `https://timoni.sh/` — Module/Instance/Bundle concepts
2. **KCL Helm plugin**: `https://github.com/kcl-lang/helm-kcl`
3. **KCL Helmfile plugin**: `https://github.com/kcl-lang/helmfile-kcl`
4. **cdk8s** (imperative): `https://cdk8s.io/docs/`

## Trusted Fetch URLs Quick Reference

```
# KCL ecosystem
https://www.kcl-lang.io/docs/reference/lang/spec/
https://www.kcl-lang.io/docs/reference/lang/spec/schema
https://www.kcl-lang.io/docs/reference/model/overview
https://www.kcl-lang.io/docs/tools/cli/kcl/overview

# Nushell
https://www.nushell.sh/book/
https://www.nushell.sh/commands/

# Crossplane
https://docs.crossplane.io/latest/concepts/compositions/
https://docs.crossplane.io/latest/concepts/composite-resource-definitions/
https://docs.crossplane.io/latest/concepts/composition-functions/

# Key GitHub repos (fetch raw content via raw.githubusercontent.com)
https://raw.githubusercontent.com/vfarcic/crossplane-kubernetes/main/CLAUDE.md
https://raw.githubusercontent.com/kcl-lang/kcl/main/CLAUDE.md

# Platform engineering
https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model
https://www.kusionstack.io/docs/
```

## When NOT to Fetch

- **Never fetch from localhost, private IPs, or cloud metadata** (see SECURITY.md)
- **Don't fetch when local docs suffice** — check skills, instructions, and docs/ first
- **Don't fetch repeatedly for the same info** — cache key findings in session memory
- **Don't fetch large codebases** — use targeted file/README fetches

## Knowledge Confidence Rating

After researching, internally rate your confidence:

| Level | Meaning | Action |
|---|---|---|
| **HIGH** | Verified against official docs + working examples | Proceed with implementation |
| **MEDIUM** | Verified against docs OR examples (not both) | Implement but note uncertainty to user |
| **LOW** | Based only on AI training data or analogies | Tell user explicitly, suggest verification via `kcl run` |

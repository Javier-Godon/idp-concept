# CLAUDE.md

Purpose: minimal, discoverable guide for Claude Code.

## Read First (in order)

1. `.github/copilot-instructions.md`
2. `.github/docs/README.md`
3. `docs/README.md`
4. `docs/operations/SECURITY.md`

## AI Docs Index (.github)

- Core references: `.github/docs/AI_REFERENCE.md`, `.github/docs/KCL_REFERENCE.md`, `.github/docs/REFERENCE_RESOURCES.md`
- AI workflow/plans: `.github/docs/AI_OPTIMIZATION_PLAN.md`, `.github/docs/PROMPT_FILES.md`, `.github/docs/FRAMEWORK_GENERALIZATION_PLAN.md`
- Task instructions: `.github/instructions/acceptance-testing.instructions.md`, `.github/instructions/crossplane-architecture.instructions.md`, `.github/instructions/framework-builders.instructions.md`, `.github/instructions/kcl-module-system.instructions.md`
- Skills (load only when needed): `.github/skills/acceptance-testing/SKILL.md`, `.github/skills/crossplane-architecture/SKILL.md`, `.github/skills/kcl-language/SKILL.md`, `.github/skills/knowledge-research/SKILL.md`
- Prompt templates: `.github/prompts/*.prompt.md`

## Project Docs Index (outside .github)

- Security: `docs/operations/SECURITY.md`, `docs/operations/SUPPLY_CHAIN_SECURITY.md`
- Testing: `docs/testing/ACCEPTANCE_TESTING.md`, `docs/testing/ACCEPTANCE_DEPENDENCIES.md`, `docs/testing/ACCEPTANCE_RUNTIME.md`, `docs/testing/TESTING_STRATEGY.md`
- Architecture/strategy: `docs/platform-engineering/PROJECT_ARCHITECTURE.md`, `docs/strategy/PLATFORM_COMPARISON_AND_KCL_ANALYSIS.md`

## Task Router

- Crossplane work (`crossplane_v2/`, crossplane render): load crossplane instruction + skill first.
- Acceptance work (fixtures, `scripts/acceptance_*`, testing docs): load acceptance instruction + skill first.
- Builders/templates: load framework-builders instruction first.
- `kcl.mod` / module resolution errors: load kcl-module-system instruction first.

## Guardrails

1. Keep context loading minimal (task-scoped).
2. Reuse existing project patterns before inventing new ones.
3. No secrets in code.
4. Pin versions; no floating `latest`.
5. Never fetch localhost/private/internal IPs.
6. Prefer smallest safe change.

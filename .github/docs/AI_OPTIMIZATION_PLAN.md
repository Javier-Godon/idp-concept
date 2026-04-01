# AI Assistant Optimization Plan for idp-concept

## Objective

Make any AI coding assistant (GitHub Copilot, Claude, etc.) an **expert** in the idp-concept project by providing it with maximum context about the technologies, patterns, and conventions used. This document describes what tools, configurations, and knowledge sources are needed and how to set them up.

---

## Table of Contents

- [1. Current State Assessment](#1-current-state-assessment)
- [2. Knowledge Gaps & Challenges](#2-knowledge-gaps--challenges)
- [3. Strategy Overview](#3-strategy-overview)
- [4. Security Policy](#4-security-policy)
- [5. GitHub Copilot Custom Instructions](#5-github-copilot-custom-instructions)
- [6. MCP Servers (Model Context Protocol)](#6-mcp-servers-model-context-protocol)
- [7. Reference Resources & Knowledge Base](#7-reference-resources--knowledge-base)
- [8. RAG (Retrieval-Augmented Generation)](#8-rag-retrieval-augmented-generation)
- [9. VS Code Extensions & Configuration](#9-vs-code-extensions--configuration)
- [10. Custom Copilot Skills & Prompt Files](#10-custom-copilot-skills--prompt-files)
- [11. Documentation Strategy](#11-documentation-strategy)
- [12. Implementation Roadmap](#12-implementation-roadmap)
- [13. Maintenance & Updates](#13-maintenance--updates)

---

## 1. Current State Assessment

### Technologies the AI Must Master

| Technology | AI Training Data Quality | Project-Specific Challenges |
|---|---|---|
| **KCL** | **LOW** — KCL is niche, limited training data | Schema inheritance, union operators, `.instance` pattern, `kcl.mod` dependencies |
| **Nushell** | **LOW-MEDIUM** — Newer language, evolving syntax | String interpolation syntax `$"..($var).."`, path operations, `match` expressions |
| **Crossplane** | **MEDIUM** — Well documented but complex | Pipeline compositions, XRDs under custom API groups, function chains |
| **ArgoCD** | **HIGH** — Widely used, well documented | CRD-to-KCL auto-generated models (36K+ lines), Application specs |
| **Helm/Helmfile** | **HIGH** — Very common | KCL schema representations of Chart.yaml, helmfile.yaml |
| **Kusion** | **LOW** — Niche ecosystem | KusionResource spec generation, `dependsOn` chains |
| **Kubernetes** | **HIGH** — Extensive training data | Standard K8s manifests, CRDs (Strimzi, cert-manager, Keycloak) |
| **go-task** | **MEDIUM** — Popular task runner | Taskfile YAML with Nushell integration |

### Key Insight
The main gap is **KCL**, **Nushell**, and **Kusion** — these are the technologies where AI assistants have the least training data and will make the most mistakes.

---

## 2. Knowledge Gaps & Challenges

### KCL-Specific Gaps
1. **Schema inheritance syntax**: `schema Child(Parent):` — AI may confuse with Python classes
2. **Union operator `|`**: Config merging — AI may not understand override semantics
3. **`$type` escape**: KCL reserves `type`, so Kubernetes `.type` fields must use `$type`
4. **`option("key")`**: CLI parameter injection from `-D key=value`
5. **`manifests.yaml_stream()`**: Built-in function for multi-doc YAML — AI may not know it exists
6. **`kcl.mod` dependency resolution**: How imports resolve across packages

### Nushell-Specific Gaps
1. **String interpolation**: `$"text ($var) more"` — different from bash/Python
2. **Path operations**: `path basename`, `path dirname`, `path expand` — custom Nushell commands
3. **Pipe-based data flow**: Everything is structured data, not text
4. **`^command`**: Prefix for external commands
5. **`$env.FILE_PWD`**: Directory of the script file itself

### Project-Pattern Gaps
1. **Schema + Instance dual pattern**: AI must understand why both exist
2. **Configuration merge chain**: kernel → profile → tenant → site
3. **Factory pattern**: factory_seed.k + *_builder.k per output format
4. **Module inheritance**: How modules extend Component/Accessory

---

## 3. Strategy Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AI KNOWLEDGE LAYERS                       │
│                                                             │
│  Layer 1: .github/copilot-instructions.md                   │
│  ├── Automatically loaded by Copilot on every interaction   │
│  └── Project conventions, patterns, tech-specific rules     │
│                                                             │
│  Layer 2: .github/prompts/*.prompt.md (Copilot Skills)      │
│  ├── Reusable task-specific prompts                         │
│  └── "Create a new KCL module", "Add a tenant", etc.       │
│                                                             │
│  Layer 3: MCP Servers (Live Documentation Access)           │
│  ├── KCL docs fetcher                                       │
│  ├── Crossplane docs fetcher                                │
│  ├── Nushell docs fetcher                                   │
│  └── Filesystem context (project structure)                 │
│                                                             │
│  Layer 4: docs/ folder (Human + AI readable docs)           │
│  ├── Architecture documentation                             │
│  ├── Technology reference guides                            │
│  ├── Pattern catalogs with examples                         │
│  └── AI reads these when #file referenced                   │
│                                                             │
│  Layer 5: In-code KCL docstrings + comments                 │
│  ├── Schema docstrings explain purpose                      │
│  └── Inline comments explain non-obvious patterns           │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Security Policy

> **Security is non-negotiable.** Every tool, extension, MCP server, and external dependency must be official, well-maintained, and evaluated before adoption.

A comprehensive security policy is maintained in [`docs/SECURITY.md`](SECURITY.md). Key principles:

1. **Only official, mainstream tools** — No experimental, abandoned, or community-only MCP servers
2. **Minimal privilege** — Every tool gets the minimum access it needs
3. **No secrets in code** — Tokens and credentials via environment variables only
4. **Defense in depth** — Multiple security layers, never rely on just one
5. **Audit everything** — All tools pass an 8-point evaluation checklist before approval

### Tool Evaluation in SECURITY.md

Before adding any new tool to the project, check:
- Provenance (reputable org), License (OSI-approved), Maintenance (active), Security Policy (exists), Adoption (>100 stars or major org), Dependencies (auditable), Data handling (no exfiltration), Install method (official registries)

### See Also
- **[SECURITY.md](SECURITY.md)** — Full security policy with approved tools registry, mcp-server-fetch detailed assessment, and incident response
- **[REFERENCE_RESOURCES.md](REFERENCE_RESOURCES.md)** — Only pre-vetted, trusted resources

---

## 5. GitHub Copilot Custom Instructions

### Location: `.github/copilot-instructions.md`

**Already created.** This file is automatically loaded by GitHub Copilot in VS Code for every interaction. It contains:

- Project identity and goals
- Technology-specific syntax rules (KCL, Nushell, Crossplane)
- Architecture overview (single source of truth pattern)
- Directory mapping and module types
- Code conventions (Schema+Instance, private variables, factory pattern)
- Output format generation rules

### Maintenance
Update this file whenever:
- New technologies are added
- New patterns or conventions emerge
- New output formats are supported

---

## 6. MCP Servers (Model Context Protocol)

MCP servers allow Copilot to fetch **live documentation** from external sources during conversations. This is critical for KCL, Nushell, and Crossplane since AI training data is limited.

### 6.1 Recommended MCP Servers

> **Security note**: All MCP servers in this project are evaluated in [SECURITY.md](SECURITY.md). Only servers from the official `modelcontextprotocol` organization or verified publishers (GitHub, Microsoft) are approved.

#### a) `fetch` MCP Server (Web Documentation Access)

**Purpose**: Allows the AI to fetch documentation pages on-demand from KCL, Nushell, Crossplane, and other technology websites.

**Configuration** (`.vscode/mcp.json`) — **runs in hardened Docker container** (see [SECURITY.md](SECURITY.md) for full details):
```json
{
  "servers": {
    "fetch": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--read-only",
        "--cap-drop=ALL",
        "--security-opt=no-new-privileges:true",
        "--memory=512m",
        "--cpus=0.5",
        "--pids-limit=50",
        "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m",
        "mcp/fetch"
      ]
    }
  }
}
```

Docker provides process/network/filesystem isolation that eliminates the critical SSRF risk of the previous `uvx` approach. The container's localhost is isolated from the host, cloud metadata endpoints are unreachable, and the filesystem is read-only.

**Key URLs to save**:
- KCL Language Spec: `https://www.kcl-lang.io/docs/reference/lang/spec/`
- KCL Schema: `https://www.kcl-lang.io/docs/reference/lang/spec/schema`
- KCL Built-in Functions: `https://www.kcl-lang.io/docs/reference/model/overview`
- KCL CLI Tools: `https://www.kcl-lang.io/docs/tools/cli/kcl/overview`
- Nushell Commands: `https://www.nushell.sh/commands/`
- Nushell Language: `https://www.nushell.sh/book/`
- Crossplane Compositions: `https://docs.crossplane.io/latest/concepts/compositions/`
- Crossplane XRDs: `https://docs.crossplane.io/latest/concepts/composite-resource-definitions/`
- Kusion Docs: `https://www.kusionstack.io/docs/`

#### b) `filesystem` MCP Server (Extended File Access)

**Purpose**: Gives the AI deeper read access to the project tree beyond the normal VS Code context. Useful when navigating the deeply nested release/pre_release structures.

**Configuration** (`.vscode/mcp.json`):
```json
{
  "servers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@anthropic-ai/mcp-filesystem",
        "/path/to/idp-concept"
      ],
      "description": "Access project files for deep code analysis"
    }
  }
}
```

#### c) `github` MCP Server (Repository Context)

**Purpose**: Allows the AI to browse GitHub issues, PRs, and code of upstream projects (KCL, Crossplane, etc.) for latest changes and patterns.

**Configuration** (`.vscode/mcp.json`):
```json
{
  "servers": {
    "github": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${input:github-token}"
      },
      "description": "Access GitHub repos for KCL, Crossplane examples"
    }
  }
}
```

### 6.2 Complete MCP Configuration

See `.vscode/mcp.json` for the current configuration. The `fetch` server runs in a hardened Docker container (see [SECURITY.md](SECURITY.md) for details).

```json
{
  "servers": {
    "fetch": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--read-only", "--cap-drop=ALL",
        "--security-opt=no-new-privileges:true",
        "--memory=512m", "--cpus=0.5", "--pids-limit=50",
        "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m",
        "mcp/fetch"
      ]
    }
  }
}
```

### 6.3 Future MCP Servers to Watch

| MCP Server | Purpose | Status |
|---|---|---|
| `mcp-server-kcl` | Native KCL language server integration | Not yet available — watch kcl-lang GitHub |
| `mcp-server-kubernetes` | Live K8s cluster introspection | Available via community |
| `mcp-server-crossplane` | Crossplane resource inspection | Not yet available |

---

## 7. Reference Resources & Knowledge Base

A curated knowledge base of **official, verified** reference repositories and documentation is maintained in [`docs/REFERENCE_RESOURCES.md`](REFERENCE_RESOURCES.md).

### Key Reference Repos

| Repository | Stars | Relevance |
|---|---|---|
| [kcl-lang/kcl](https://github.com/kcl-lang/kcl) | 2,300+ | KCL language core, has CLAUDE.md, CNCF Sandbox |
| [kcl-lang/modules](https://github.com/kcl-lang/modules) | 39+ | 200+ official KCL modules (crossplane, argocd, strimzi, cert-manager) |
| [vfarcic/crossplane-kubernetes](https://github.com/vfarcic/crossplane-kubernetes) | 50+ | **Closest match**: 66% KCL + 30.6% Nushell, Crossplane compositions, CLAUDE.md |
| [crossplane-contrib/function-kcl](https://github.com/crossplane-contrib/function-kcl) | 150+ | Canonical KCL-in-Crossplane function (used in our crossplane_v2/) |
| [vfarcic/dot-ai](https://github.com/vfarcic/dot-ai) | 308+ | MCP-based DevOps AI toolkit, Nushell + K8s |
| [vfarcic/cncf-demo](https://github.com/vfarcic/cncf-demo) | 231+ | End-to-end CNCF stack (Crossplane, ArgoCD, Helm), IDP chapter |
| [kcl-lang/konfig](https://github.com/kcl-lang/konfig) | 14+ | KCL K8s abstraction framework (similar to our framework/) |
| [kcl-lang/krm-kcl](https://github.com/kcl-lang/krm-kcl) | 34+ | KRM spec bridging KCL to Helm, Helmfile, Crossplane |
| [KusionStack/kusion](https://github.com/KusionStack/kusion) | 1,287+ | IDP orchestrator, deep KCL integration |
| [cncf/tag-app-delivery](https://github.com/cncf/tag-app-delivery) | 833+ | Platform Engineering Maturity Model, Platforms Whitepaper |

### For AI Assistants

When the AI needs patterns or examples beyond this project:
1. **Fetch KCL docs** from `kcl-lang.io` for syntax questions
2. **Reference kcl-lang/modules** for schema design patterns
3. **Check vfarcic/cncf-demo** for Crossplane + ArgoCD integration patterns
4. **Only fetch from trusted domains** listed in [SECURITY.md](SECURITY.md)

See [REFERENCE_RESOURCES.md](REFERENCE_RESOURCES.md) for the complete resource guide.

---

## 8. RAG (Retrieval-Augmented Generation)

### 8.1 Why RAG

The project contains large auto-generated files (ArgoCD models: 36K+ lines, Strimzi CRDs: 19K+ lines) that exceed AI context windows. RAG enables the AI to search and retrieve specific sections on demand.

### 8.2 Built-in RAG (Copilot Workspace Indexing)

GitHub Copilot in VS Code already indexes the workspace for `@workspace` queries. To optimize this:

1. **Ensure `.gitignore` doesn't exclude important files**: KCL output files in `output/` should be accessible
2. **Keep documentation in plain text/markdown**: The `docs/` folder is fully indexable
3. **Use descriptive file names**: `kafka_single_instance_module_def.k` is searchable; `module1.k` is not

### 8.3 Custom RAG via Documentation Files

The `docs/` folder acts as a searchable knowledge base. We create focused reference documents that the AI can use with `#file:docs/KCL_REFERENCE.md` in chat:

| Document | Purpose |
|---|---|
| `docs/KCL_REFERENCE.md` | KCL syntax, patterns, and gotchas specific to this project |
| `docs/NUSHELL_REFERENCE.md` | Nushell syntax and patterns used in the CLI |
| `docs/CROSSPLANE_PATTERNS.md` | Crossplane composition patterns used in the project |
| `docs/PROJECT_ARCHITECTURE.md` | Full architecture documentation |
| `docs/FRAMEWORK_SCHEMAS.md` | All framework schemas with field descriptions |
| `docs/SECURITY.md` | Security policy, tool evaluation criteria, approved tools registry |
| `docs/REFERENCE_RESOURCES.md` | Curated reference repos and knowledge base |

### 8.4 RAG Enhancement Strategies

For more advanced setups:

1. **Chroma/Qdrant local vector store**: Index all KCL documentation, Crossplane docs, and Nushell book locally for fast semantic search
2. **Custom VS Code extension**: Build a thin extension that provides technology-specific context to Copilot via the Language Model API
3. **Pre-processed knowledge bases**: Convert KCL spec, Nushell book, and Crossplane docs to markdown chunks optimized for AI retrieval

---

## 9. VS Code Extensions & Configuration

### 9.1 Required Extensions

| Extension | Purpose |
|---|---|
| **kcl.kcl-vscode-extension** | KCL language support (syntax, completion, diagnostics) |
| **GitHub.copilot** | AI coding assistant |
| **GitHub.copilot-chat** | Copilot Chat interface |
| **redhat.vscode-yaml** | YAML schema validation (Crossplane, K8s, Helmfile) |
| **ms-kubernetes-tools.vscode-kubernetes-tools** | Kubernetes manifest support |
| **thenuprojectcontributors.vscode-nushell-lang** | Nushell syntax highlighting |
| **task.vscode-task** | go-task/Taskfile support |

### 9.2 VS Code Settings (`.vscode/settings.json`)

```json
{
  "files.associations": {
    "*.k": "kcl",
    "kcl.mod": "toml",
    "kcl.mod.lock": "toml",
    "koncept": "shellscript",
    "koncepttask": "shellscript",
    "taskfile.yaml": "yaml"
  },
  "yaml.schemas": {
    "https://json.schemastore.org/helmfile.json": "helmfile.yaml",
    "https://json.schemastore.org/chart.json": "Chart.yaml",
    "https://json.schemastore.org/taskfile.json": "taskfile.yaml"
  },
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/copilot-instructions.md" }
  ],
  "github.copilot.chat.reviewSelection.instructions": [
    { "text": "When reviewing KCL code: check schema inheritance, verify $type usage for Kubernetes type fields, ensure .instance pattern is used correctly, validate kcl.mod imports." }
  ],
  "github.copilot.chat.testGeneration.instructions": [
    { "text": "For KCL testing, use kcl-test framework. Test files should be named *_test.k. Use assert statements to validate schema instances." }
  ],
  "[kcl]": {
    "editor.tabSize": 4,
    "editor.insertSpaces": true
  },
  "search.exclude": {
    "**/strimzi-crds-*.yaml": true,
    "**/cert_manager_v*.yaml": true,
    "**/kcl.mod.lock": true
  }
}
```

---

## 10. Custom Copilot Skills & Prompt Files

### 10.1 What are Prompt Files?

Prompt files (`.github/prompts/*.prompt.md`) are reusable task-specific prompts that appear in the Copilot Chat slash command menu. They encode expert knowledge about common tasks.

### 10.2 Recommended Prompt Files

Create the following prompt files:

#### `.github/prompts/new-kcl-module.prompt.md`
For generating new KCL modules (Components or Accessories).

#### `.github/prompts/new-tenant.prompt.md`
For adding a new tenant with configuration overrides.

#### `.github/prompts/new-site.prompt.md`
For adding a new deployment site/environment.

#### `.github/prompts/new-release.prompt.md`
For creating a new versioned release with all factory builders.

#### `.github/prompts/new-stack.prompt.md`
For defining a new stack (combination of modules).

#### `.github/prompts/debug-kcl.prompt.md`
For debugging KCL compilation errors.

#### `.github/prompts/crossplane-composition.prompt.md`
For creating new Crossplane compositions.

See [`docs/PROMPT_FILES.md`](PROMPT_FILES.md) for the full content of each prompt file.

---

## 11. Documentation Strategy

### 11.1 Documentation Structure

```
docs/
├── PROJECT_ARCHITECTURE.md        # Full architecture (created)
├── AI_OPTIMIZATION_PLAN.md        # This document
├── SECURITY.md                    # Security policy & approved tools registry
├── REFERENCE_RESOURCES.md         # Curated reference repos & knowledge base
├── KCL_REFERENCE.md               # KCL quick reference for this project
├── NUSHELL_REFERENCE.md           # Nushell patterns used in CLI
├── CROSSPLANE_PATTERNS.md         # Crossplane composition patterns
├── FRAMEWORK_SCHEMAS.md           # All framework schema definitions
├── PROMPT_FILES.md                # Prompt file contents and usage
└── DEVELOPMENT_WORKFLOWS.md       # Common development workflows
```

### 11.2 Documentation Guidelines

1. **Write for both humans and AI**: Use code examples with inline explanations
2. **Include "AI hints"**: Sections titled "Common Mistakes" help the AI avoid known issues
3. **Cross-reference files**: Use relative links so AI can navigate
4. **Keep examples complete**: Don't truncate code examples — AI needs full context
5. **Update docs with code**: Documentation drift reduces AI effectiveness

---

## 12. Implementation Roadmap

### Phase 1: Foundation (Immediate)

| Item | Status | Impact |
|---|---|---|
| `.github/copilot-instructions.md` | **DONE** | HIGH — Loaded on every Copilot interaction |
| `docs/PROJECT_ARCHITECTURE.md` | **DONE** | HIGH — Comprehensive project docs |
| `docs/AI_OPTIMIZATION_PLAN.md` | **DONE** | HIGH — This document |
| `docs/KCL_REFERENCE.md` | **DONE** | HIGH — KCL is the biggest AI gap |
| `docs/NUSHELL_REFERENCE.md` | **DONE** | MEDIUM — Nushell CLI reference |
| `docs/CROSSPLANE_PATTERNS.md` | **DONE** | MEDIUM — Crossplane patterns |
| `docs/FRAMEWORK_SCHEMAS.md` | **DONE** | HIGH — Schema reference |
| `docs/DEVELOPMENT_WORKFLOWS.md` | **DONE** | MEDIUM — Common workflows |
| `docs/SECURITY.md` | **DONE** | **CRITICAL** — Non-negotiable security policy |
| `docs/REFERENCE_RESOURCES.md` | **DONE** | HIGH — Curated knowledge base |

### Phase 2: Interactive Tools (Week 1-2)

| Item | Priority | Impact |
|---|---|---|
| `.vscode/mcp.json` with fetch MCP | HIGH | Enables live doc fetching for KCL/Nushell/Crossplane |
| `.vscode/settings.json` optimizations | HIGH | Better file associations and schemas |
| `.github/prompts/*.prompt.md` files | MEDIUM | Reusable task-specific prompts |

### Phase 3: Advanced (Week 3-4)

| Item | Priority | Impact |
|---|---|---|
| GitHub MCP server setup | MEDIUM | Access to upstream repos |
| KCL documentation local cache | LOW | Faster RAG; depends on project growth |
| Custom VS Code extension for KCL context | LOW | Maximum AI context but high effort |

---

## 13. Maintenance & Updates

### When to Update `.github/copilot-instructions.md`
- New technology added (e.g., Timoni, cdk8s)
- New output format supported
- New conventions or patterns adopted
- Major refactoring of framework schemas

### When to Update docs/
- New project (beyond video_streaming) is fully implemented
- New Crossplane compositions added
- Framework procedures changed
- CLI commands added or modified

### Automated Checks
Consider adding CI checks:
- Verify `copilot-instructions.md` mentions all directories in `framework/`
- Verify all schemas in `framework/models/` are documented in `FRAMEWORK_SCHEMAS.md`
- Verify all prompt files reference existing patterns

---

## Summary

The optimization strategy has **5 layers**, prioritized by impact-to-effort ratio:

1. **`.github/copilot-instructions.md`** (highest impact, lowest effort) — Always loaded by Copilot
2. **`docs/` folder with focused reference guides** — Addressable via `#file:` in chat
3. **MCP servers** (medium effort) — Live documentation access for niche technologies
4. **Prompt files** (low effort) — Reusable expert patterns for common tasks
5. **RAG/vector stores** (high effort) — Only needed as the project scales significantly

The critical insight: **KCL, Nushell, and Kusion are the technologies where AI needs the most help**. All documentation and instructions should prioritize these three while assuming the AI already knows Kubernetes, Helm, and YAML well.

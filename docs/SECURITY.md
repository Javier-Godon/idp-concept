# Security Policy for AI Tools, MCP Servers & External Dependencies

> **⚠️ CRITICAL — MCP Fetch Security Model**
>
> The `mcp-server-fetch` tool runs inside a **hardened Docker container** with process, network, and filesystem isolation. This mitigates the primary SSRF risk: the container's `localhost` is isolated from the host machine, and cloud metadata endpoints (169.254.169.254) are unreachable.
>
> **Despite Docker isolation, ALL AI assistants using the fetch tool MUST:**
> 1. **NEVER fetch localhost, 127.0.0.1, 0.0.0.0, or any private/internal IP address**
> 2. **NEVER fetch URLs on local network ranges** (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
> 3. **NEVER fetch URLs with non-standard ports** unless the domain is in the trusted list below
> 4. **ONLY fetch URLs from the explicitly trusted domains** listed in this document
> 5. **NEVER follow redirects blindly** — if a trusted URL redirects to a non-trusted domain, stop
>
> Docker isolation is the **primary defense**. The software-level restrictions above are **defense-in-depth** to protect against misconfiguration or future container escape vulnerabilities.

---

## Non-Negotiable Principles

1. **Only official, mainstream, well-maintained tools** — No experimental, abandoned, or poorly maintained dependencies
2. **Minimal privilege** — Every tool gets the minimum access it needs, nothing more
3. **No secrets in code** — Tokens, keys, and credentials are NEVER committed; use environment variables or secret managers
4. **Audit everything** — Every external tool must be evaluated before adoption
5. **Defense in depth** — Assume any single layer can fail; stack multiple protections
6. **No internal network access via MCP fetch** — NEVER use the fetch tool to access localhost, private IPs, or cloud metadata endpoints

---

## Tool Evaluation Criteria

Before adding **any** external tool (MCP server, extension, CLI utility, dependency) to this project, it must pass ALL of the following checks:

| Criterion | Requirement | How to Verify |
|---|---|---|
| **Provenance** | Maintained by a known, reputable organization or individual | Check GitHub org, company backing, CNCF affiliation |
| **License** | OSI-approved open-source license (MIT, Apache 2.0, BSD) | Check LICENSE file in repo |
| **Maintenance** | Active commits within last 6 months | Check commit history, release cadence |
| **Security Policy** | Has SECURITY.md or vulnerability reporting process | Check repo root files |
| **Stars/Adoption** | >100 stars OR backed by a major org (Anthropic, GitHub, CNCF, etc.) | Check GitHub stars, users, forks |
| **Dependencies** | Minimal, auditable dependency tree | Run `npm audit`, `pip audit`, or equivalent |
| **No Data Exfiltration** | Does NOT send data to third-party servers unless explicitly needed | Review source code, network calls |
| **Reproducible Install** | Can be installed from official package registries (npm, PyPI, crates.io) | Verify registry presence |

---

## Approved Tools Registry

### MCP Servers

| Tool | Source | Status | Risk Level | Notes |
|---|---|---|---|---|
| `mcp-server-fetch` | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers/tree/main/src/fetch) | **APPROVED** | **MEDIUM** | See detailed assessment below |
| `github-mcp-server` | [github/github-mcp-server](https://github.com/github/github-mcp-server) | **APPROVED** | LOW | Official GitHub MCP server. Requires PAT with minimal scopes |
| `@anthropic-ai/mcp-filesystem` | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem) | **NOT USED** | MEDIUM | Reference server. Would need strict path restrictions. Not currently needed — VS Code built-in file access is sufficient |
| `addon-controlplane-mcp-server` | [upbound/addon-controlplane-mcp-server](https://marketplace.upbound.io/addons/upbound/addon-controlplane-mcp-server/0.1.0) | **REJECTED** | HIGH | In-cluster sidecar for Upbound Spaces — wrong use case (requires commercial Upbound platform). v0.1.0 pre-release, no open-source community, commercial vendor lock-in. Evaluated 2025. |
| `crossplane-mcp` | [vfarcic/crossplane-mcp](https://github.com/vfarcic/crossplane-mcp) | **REJECTED** | HIGH | Abandoned prototype — 1 star, 0 forks, 0 releases, 11 months stale, single contributor. No tests, no CI, incomplete implementation. Evaluated 2025. |

### VS Code Extensions

| Extension | Publisher | Status | Notes |
|---|---|---|---|
| `kcl.kcl-vscode-extension` | KCL Team (CNCF) | **APPROVED** | Official KCL language extension |
| `GitHub.copilot` | GitHub/Microsoft | **APPROVED** | Official GitHub Copilot |
| `GitHub.copilot-chat` | GitHub/Microsoft | **APPROVED** | Official Copilot Chat |
| `redhat.vscode-yaml` | Red Hat | **APPROVED** | Industry-standard YAML tooling |
| `ms-kubernetes-tools.vscode-kubernetes-tools` | Microsoft | **APPROVED** | Official K8s tools |

### CLI Tools

| Tool | Maintained By | Status | Notes |
|---|---|---|---|
| `kcl` | KCL/CNCF | **APPROVED** | CNCF Sandbox project |
| `nu` (Nushell) | Nushell Project | **APPROVED** | Well-maintained open-source shell |
| `crossplane` CLI | Upbound/CNCF | **APPROVED** | CNCF Graduated project |
| `go-task` | Task project | **APPROVED** | Popular task runner, >11K stars |
| `uv` / `uvx` | Astral (Ruff team) | **APPROVED** | High-performance Python package installer |

---

## Detailed Assessment: `mcp-server-fetch`

### Identity
- **Repository**: [modelcontextprotocol/servers/src/fetch](https://github.com/modelcontextprotocol/servers/tree/main/src/fetch)
- **Organization**: `modelcontextprotocol` — The official MCP organization (backed by Anthropic)
- **License**: MIT (existing code) / Apache 2.0 (new contributions)
- **Language**: Python
- **Install method**: Docker (`mcp/fetch` from Docker Hub, verified publisher) — previously `uvx mcp-server-fetch`
- **Docker image**: [`mcp/fetch`](https://hub.docker.com/r/mcp/fetch) — built and signed by Docker Inc., cosign-verified

### Is it 100% secure?

**No tool is 100% secure.** However, `mcp-server-fetch` is the **most trustworthy option** for web fetching via MCP because:

#### What makes it trustworthy
1. **Official reference server** — Maintained by the MCP steering group (Anthropic-backed), listed as a "Reference Server" (not community/third-party)
2. **Active maintenance** — Regular commits, bug fixes, and security patches (last update: March 2026)
3. **Proper security practices** — Has SECURITY.md with vulnerability reporting via GitHub Security Advisories
4. **Respects robots.txt** — Obeys website crawling rules by default
5. **Transparent user-agent** — Identifies itself clearly as `ModelContextProtocol/1.0`
6. **Configurable** — Proxy support, custom user-agent, robots.txt override (when explicitly needed)
7. **39K+ stars on parent repo** — Heavily scrutinized by the community
8. **Test suite included** — Has tests directory with automated testing

#### Known risks and mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| **SSRF (Server-Side Request Forgery)** — Can access local/internal IPs | **MEDIUM** (mitigated by Docker) | **Docker isolation provides the primary defense.** With Docker's default bridge network, `localhost`/`127.0.0.1` inside the container resolves to the container itself (not the host), making localhost-based SSRF attacks ineffective. Cloud metadata endpoints (169.254.169.254) timeout from inside the container. The host is only reachable via the Docker bridge IP (172.17.0.1), which is non-trivial to exploit. **Additional software mitigations:** (1) AI must NEVER request localhost/127.0.0.1/0.0.0.0, (2) NEVER request private IP ranges, (3) ONLY fetch from the trusted domain allowlist, (4) Do NOT expose the MCP server to untrusted networks. |
| **Content from untrusted sites** — AI may follow malicious instructions from fetched content | **LOW** | Only fetch from known, trusted documentation sites (kcl-lang.io, nushell.sh, docs.crossplane.io, etc.). The AI should not blindly execute code from fetched pages. |
| **Reference implementation** — Explicitly stated as "not production-ready" | **LOW** | This is acceptable for our use case (developer tooling in local environments). We are NOT deploying this in production infrastructure. |
| **Python supply chain** — Dependency on Python packages | **LOW** | Docker image is built from a locked `uv.lock` file, signed by Docker Inc. with cosign verification. Image is immutable once pulled — no runtime dependency resolution. |

#### Verdict: **APPROVED for development use**

The `mcp-server-fetch` server is approved for use in this project under these **strict conditions**:
1. **MUST run inside Docker** with the hardened configuration below — NEVER run via `uvx` or `pip` directly
2. Used ONLY on developer workstations, NEVER in CI/CD or production
3. **ONLY fetch URLs from the explicitly trusted domain allowlist below** — no exceptions
4. **NEVER fetch localhost, 127.0.0.1, 0.0.0.0, or any private/internal IP address**
5. **NEVER fetch cloud metadata endpoints** (169.254.169.254, metadata.google.internal, etc.)
6. **NEVER fetch URLs with IP addresses** — always use domain names from the trusted list
7. Do NOT use `--ignore-robots-txt` unless explicitly needed for specific documentation sites
8. Keep the Docker image updated: `docker pull mcp/fetch:latest`
9. If a URL redirects to a domain NOT on the trusted list, do NOT follow the redirect

#### Docker Security Hardening

The `.vscode/mcp.json` configuration runs `mcp-server-fetch` in a hardened Docker container with the following security controls:

```json
{
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
```

| Flag | Purpose |
|---|---|
| `--rm` | Auto-remove container after exit — no leftover state |
| `--read-only` | Read-only root filesystem — prevents malicious writes |
| `--cap-drop=ALL` | Drop ALL Linux capabilities — minimal privilege |
| `--security-opt=no-new-privileges:true` | Prevent privilege escalation via setuid/setgid |
| `--memory=512m` | Memory limit — prevents resource exhaustion DoS |
| `--cpus=0.5` | CPU limit — prevents resource exhaustion DoS |
| `--pids-limit=50` | Process limit — prevents fork bombs |
| `--tmpfs /tmp:rw,noexec,nosuid,size=64m` | Ephemeral writable /tmp with no-exec — needed for Python but prevents code execution from /tmp |

**Why Docker instead of uvx?**

| Aspect | `uvx` (previous) | Docker (current) |
|---|---|---|
| **Process isolation** | Runs as your user, full host access | Runs in isolated namespace, no host filesystem access |
| **Network isolation** | `localhost` = host's localhost (SSRF risk) | `localhost` = container's localhost (SSRF mitigated) |
| **Cloud metadata** | Can reach 169.254.169.254 | Times out — cannot reach metadata endpoint |
| **Filesystem** | Full read/write to host | Read-only root, ephemeral /tmp only |
| **Capabilities** | Full user capabilities | ALL capabilities dropped |
| **Supply chain** | Resolves deps at runtime from PyPI | Immutable image with locked, signed deps |
| **Resource limits** | None — can consume unlimited resources | Hard memory/CPU/PID limits |

### Recommended Fetch Targets (Trusted URLs)

**AI assistants MUST refuse to fetch any URL not matching these domains.** This is a hard constraint, not a suggestion.

```
# KCL ecosystem (CNCF Sandbox)
https://www.kcl-lang.io/*
https://artifacthub.io/packages/search?org=kcl*

# Nushell (open source shell)
https://www.nushell.sh/*

# Crossplane (CNCF Graduated)  
https://docs.crossplane.io/*
https://marketplace.upbound.io/*

# Kubernetes ecosystem
https://kubernetes.io/*
https://helm.sh/*
https://helmfile.readthedocs.io/*

# Kusion (open source IDP framework)
https://www.kusionstack.io/*

# ArgoCD (CNCF Graduated)
https://argo-cd.readthedocs.io/*

# Strimzi (CNCF Sandbox)
https://strimzi.io/*

# Infrastructure components docs
https://cert-manager.io/*
https://www.keycloak.org/*

# GitHub repos (for source code reference)
https://github.com/kcl-lang/*
https://github.com/crossplane/*
https://github.com/crossplane-contrib/*
https://github.com/vfarcic/*
https://github.com/modelcontextprotocol/*
https://github.com/github/*
https://github.com/KusionStack/*
https://github.com/stefanprodan/*
https://github.com/cncf/*
https://github.com/score-spec/*
https://github.com/syntasso/*
https://github.com/k0rdent/*
https://github.com/rancher/*
https://raw.githubusercontent.com/*/main/*
https://raw.githubusercontent.com/*/refs/heads/main/*

# Platform engineering references
https://tag-app-delivery.cncf.io/*
https://score.dev/*
https://timoni.sh/*
https://kustomize.io/*
https://cdk8s.io/*
https://docs.k0rdent.io/*
https://fleet.rancher.io/*

# BLOCKED — NEVER fetch these (examples, not exhaustive)
# http://localhost:*
# http://127.0.0.1:*
# http://0.0.0.0:*
# http://10.*
# http://172.16.* through http://172.31.*
# http://192.168.*
# http://169.254.169.254/* (cloud metadata)
# http://metadata.google.internal/*
# Any raw IP address
```

---

## Detailed Assessment: `github-mcp-server`

### Identity
- **Repository**: [github/github-mcp-server](https://github.com/github/github-mcp-server)
- **Organization**: `github` — Official GitHub organization (Microsoft-backed)
- **License**: MIT

### Security Configuration

If/when the GitHub MCP server is added:

1. **Create a dedicated Personal Access Token (PAT)** with MINIMAL scopes:
   - `public_repo` only (read access to public repos)
   - Do NOT grant `repo` (full private repo access) unless absolutely necessary
   - Do NOT grant `admin:*`, `write:*`, or `delete:*` scopes
2. **Store the PAT** in environment variables, NEVER in committed files
3. **Use `${input:github-token}`** in MCP config to prompt at runtime (no hardcoding)
4. **Rotate the token** at least every 90 days

---

## Security Rules for AI-Generated Code

When an AI assistant generates code for this project:

1. **Never trust AI-generated secrets** — If AI suggests hardcoded credentials, reject immediately
2. **Validate all generated KCL schemas** — Run `kcl run` to verify compilation
3. **Review Crossplane compositions carefully** — AI may generate overly permissive RBAC
4. **Check Kubernetes manifests** — Verify no `privileged: true`, no `hostNetwork: true`, no excessive capabilities
5. **Validate Nushell scripts** — Ensure no `rm -rf`, no unchecked `^` external commands on user input
6. **Pin dependency versions** — AI may suggest floating versions; always pin to specific versions in `kcl.mod`

---

## Incident Response

If a security issue is found in any approved tool:

1. **Immediately stop using the affected tool**
2. **Check for updates/patches** from the upstream project
3. **Document the issue** in this file under the tool's assessment section
4. **Evaluate alternatives** if the issue is not resolved within 30 days
5. **Update `.vscode/mcp.json`** to remove or disable the affected server

---

## Review Schedule

- **Monthly**: Check for updates to all MCP servers and extensions
- **Quarterly**: Re-evaluate the approved tools registry
- **On incident**: Immediate review of affected tool
- **On addition**: Every new tool must go through the evaluation criteria above before being added to any configuration file

---

*Last reviewed: 2026-03-30*
*Next scheduled review: 2026-06-30*

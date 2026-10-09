# Tooling Setup

> Complete guide to installing all tools required for **idp-concept** development.
> Covers local (user-scoped) vs global (system-wide) installation — with pros and cons for each.

---

## Tool Inventory

| Tool | Used For | Required? | Version Needed |
|---|---|---|---|
| **koncept Go CLI** | Primary scaffold/render/validate/policy interface | **REQUIRED** | Download a [GitHub Release](https://github.com/Javier-Godon/idp-concept/releases) binary (published since `v1.0.0`) |
| **Go** (`go`) | Builds the `koncept` CLI from source | Optional (contributors only) | v1.23+ |
| **KCL** (`kcl`) | Direct KCL troubleshooting; installed in the CI image | Recommended locally | v0.11+ |
| **kubeconform** | Validates rendered K8s manifests against schemas | Recommended | Latest |
| **Helm** (`helm`) | Lints and templates Helm charts | Recommended | v3+ |
| **go-task** (`task`) | Task runner used by project Taskfile templates | Optional | v3+ |
| **helmfile** | Manages Helmfile deployments | Optional | v0.169+ |
| **kubectl** | Interacts with live Kubernetes clusters | Optional | v1.28+ |

> The Go CLI is the single user path for scaffold/render/validate/policy workflows. `kcl` is
> only needed locally for direct troubleshooting; everything else is optional.

For Windows/company laptops, prefer WSL2 + Docker Desktop + kind and see [../developer/WINDOWS_LOCAL_SETUP.md](../developer/WINDOWS_LOCAL_SETUP.md) for local footprint and Ceph guidance.

---

## TL;DR — Quick Install (Ubuntu 24.04)

Install everything you need for this project without root access, into your user account:

```bash
# 1. koncept Go CLI — prebuilt release binary (linux-amd64 shown; also linux-arm64,
#    darwin-amd64, darwin-arm64, windows-amd64.exe)
KONCEPT_VERSION="v1.0.5"  # latest at https://github.com/Javier-Godon/idp-concept/releases
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/koncept \
  "https://github.com/Javier-Godon/idp-concept/releases/download/${KONCEPT_VERSION}/koncept-linux-amd64"
chmod +x ~/.local/bin/koncept

# 2. KCL — useful for direct troubleshooting
#   OR user-local (no root):
KCL_VERSION="v0.11.0"  # update to latest from https://github.com/kcl-lang/cli/releases
mkdir -p ~/.local/bin
curl -fsSL "https://github.com/kcl-lang/cli/releases/download/${KCL_VERSION}/kcl-${KCL_VERSION}-linux-amd64.tar.gz" \
  | tar -xz -C ~/.local/bin
# The tarball extracts 'kcl' directly

# 3. kubeconform — optional, for manifest validation
KUBECONFORM_VERSION="v0.7.0"
curl -fsSL "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
  | tar -xz -C ~/.local/bin kubeconform

# 4. go-task — optional, for project Taskfile templates
TASK_VERSION="v3.43.3"
curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.tar.gz" \
  | tar -xz -C ~/.local/bin task

# Make sure ~/.local/bin is in your PATH (usually already set on Ubuntu 24.04)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
koncept --version && kcl version && kubeconform -v
```

---

## Installation Options Explained

### Option A — User-Local Install (`~/.local/bin`)

Install tools to your home directory. No `sudo` required. Available to all your projects.

| Pros | Cons |
|---|---|
| No `sudo` / root required | Only for your user account on this machine |
| Doesn't affect other users | Must ensure `~/.local/bin` is in `$PATH` |
| Works across all your projects | Manually manage upgrades |
| Standard Unix convention (XDG Base Dir) | Tool version shared across all projects |

**When to use**: Single developer workstation, laptop, dev container. **Recommended default.**

---

### Option B — System-Wide Install (`/usr/local/bin`)

Install tools for all users on the machine. Requires `sudo`.

| Pros | Cons |
|---|---|
| Available to all users | Requires `sudo` |
| No PATH configuration needed | Can conflict with other users' version needs |
| CI/CD machines typically already set up this way | System package upgrades may conflict |

**When to use**: Shared servers, CI/CD agents, Docker build images.

---

### Option C — Project-Local Install (via mise)

[mise](https://mise.jdx.dev/) is a dev tool version manager (similar to asdf/rbenv/nvm but for all tools). It reads `.mise.toml` from the project directory and installs pinned versions without requiring root.

| Pros | Cons |
|---|---|
| Different version per project (pin exact versions) | One-time `mise` install step |
| Reproducible: commit `.mise.toml` to Git | Tools stored in `~/.local/share/mise/` (not truly in the repo dir) |
| No system-wide installation needed | Tools stored in a shared cache, not the repo dir |
| Automatic version switching when entering project dir | Not all tools have mise plugins |

**When to use**: Team projects where tool version consistency matters; prevents "works on my machine" issues.

**mise does NOT isolate binaries inside the project folder** — it manages versioned installs in a shared cache (`~/.local/share/mise/`) and activates them per-directory. The key benefit is automatic version pinning, not isolation.

---

## koncept Go CLI

**Why**: This is the primary supported interface for product teams. It includes project/module/env/release scaffolding, rendering, validation, policy checks, golden drift checks, changelog fragments, dependency diagnostics, and `doctor`.

> "koncept" and "koncept Go CLI" are the same single binary (written in Go). If you already ran
> step 1 of the TL;DR, it is installed — this section only adds details and alternatives.
> You do **not** need Go installed to use it; Go is only needed to build from source.

### Install: Release Binary (Recommended)

Each [GitHub Release](https://github.com/Javier-Godon/idp-concept/releases) publishes, per platform (`linux-amd64`, `linux-arm64`, `darwin-amd64`, `darwin-arm64`, `windows-amd64.exe`): the raw binary, a `.tar.gz`/`.zip` archive, a cosign `.bundle`, a CycloneDX `.sbom.xml`, and a `SHA256SUMS` file.

```bash
KONCEPT_VERSION="v1.0.5"
OS=linux ARCH=amd64   # linux|darwin, amd64|arm64
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/koncept \
  "https://github.com/Javier-Godon/idp-concept/releases/download/${KONCEPT_VERSION}/koncept-${OS}-${ARCH}"
chmod +x ~/.local/bin/koncept
koncept --version
mkdir -p ~/.local/share/bash-completion/completions
koncept completion bash > ~/.local/share/bash-completion/completions/koncept
```

Verify the download (run next to the downloaded binary):

```bash
curl -fsSLO "https://github.com/Javier-Godon/idp-concept/releases/download/${KONCEPT_VERSION}/SHA256SUMS"
sha256sum --ignore-missing -c SHA256SUMS
```

For cosign signature and SLSA provenance verification see [SUPPLY_CHAIN_SECURITY.md](SUPPLY_CHAIN_SECURITY.md).

> **Use `v1.0.5` or later.** In `v1.0.0` the published `SHA256SUMS` does not match the binaries
> (fixed by the reproducible build in `cmd/koncept/Makefile`); only its cosign bundle verifies.
> `v1.0.4` has checksums and signatures but no SLSA provenance; `v1.0.5`+ include `koncept.intoto.jsonl`.

### Install: Build From Source (contributors)

```bash
cd /path/to/idp-concept/cmd/koncept
make build
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/koncept" ~/.local/bin/koncept
koncept --version
```

Release packaging: `make build-all`, `make checksums`, `make dist-archives`, `make docker`. Pushing a `v*` tag runs [release.yml](../../.github/workflows/release.yml), which publishes binaries, SBOMs and cosign bundles to the GitHub Release and pushes the image to `ghcr.io/javier-godon/idp-concept/koncept` (not anonymously pullable unless the GHCR package is made public).

---

## KCL

**Why**: Required for all KCL compilation, rendering, and testing (`kcl run`, `kcl test`, `kcl mod`).

### Install: Official Script (System-Wide — Linux)

Installs to `/usr/local/bin/kcl`:

```bash
# Requires sudo — installs to /usr/local/bin
wget -q https://kcl-lang.io/script/install-cli.sh -O - | /bin/bash
kcl version
```

### Install: User-Local (No Root — Linux)

```bash
KCL_VERSION="v0.11.0"
mkdir -p ~/.local/bin
TMP=$(mktemp -d)
curl -fsSL "https://github.com/kcl-lang/cli/releases/download/${KCL_VERSION}/kcl-${KCL_VERSION}-linux-amd64.tar.gz" \
  | tar -xz -C "$TMP"
cp "$TMP/kcl" ~/.local/bin/kcl
chmod +x ~/.local/bin/kcl
rm -rf "$TMP"
kcl version
```

### Install: Via mise

```toml
# .mise.toml
[tools]
kcl = "0.11.0"
```

### KCL Language Server (VS Code Extension)

```bash
# Install KCL language server for VS Code IntelliSense:
wget -q https://kcl-lang.io/script/install-kcl-lsp.sh -O - | /bin/bash
# Then install the VS Code extension: kcl.kcl-vscode-extension
```

---

## kubeconform

**Why**: Validates rendered Kubernetes manifests against official schemas. Use after `koncept render argocd` to catch structural errors before pushing to Git.

```bash
# User-local install
KUBECONFORM_VERSION="v0.7.0"
curl -fsSL "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
  | tar -xz -C ~/.local/bin kubeconform
kubeconform -v

# Usage:
koncept render argocd
kubeconform -summary output/*.yaml
```

---

## Helm

**Why**: For linting and templating Helm charts generated by `koncept render helmfile`.

### Install: Official Script (System-Wide)

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Install: User-Local

```bash
HELM_VERSION="v3.17.0"
TMP=$(mktemp -d)
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | tar -xz -C "$TMP"
cp "$TMP/linux-amd64/helm" ~/.local/bin/helm
rm -rf "$TMP"
helm version --short
```

---

## go-task

**Why**: Task runner used by the project Taskfile templates. Not required if you only use `koncept` directly.

```bash
# User-local install
TASK_VERSION="v3.43.3"
curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.tar.gz" \
  | tar -xz -C ~/.local/bin task
task --version
```

---

## helmfile

**Why**: Manages Helmfile deployments (deploying to a cluster). Not required for rendering/generating output files — only needed to actually deploy.

```bash
# User-local install
HELMFILE_VERSION="v0.171.0"
curl -fsSL "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64.tar.gz" \
  | tar -xz -C ~/.local/bin helmfile
helmfile --version
```

---

## Recommended Setup: mise `.mise.toml`

For team environments where tool version consistency matters, commit a `.mise.toml` to the project root. Every developer runs `mise install` once and gets identical versions.

Create `/path/to/idp-concept/.mise.toml`:

```toml
[tools]
kcl           = "0.11.0"
# kubeconform is available via the 'ubi' plugin
# helm via 'helm' plugin (mise has native helm support on some distros)

[env]
# Ensure project-local tools are on PATH when in this directory
PATH = "{{env.PATH}}"
```

```bash
# Install mise (user-local):
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# In the project directory:
cd idp-concept
mise install            # Installs all tools from .mise.toml
mise list               # Verify installed versions
```

---

## Verifying Your Setup

Run this checklist after setup:

```bash
# Check all tools are on PATH and print versions:
kcl version             # v0.11.x
kubeconform -v          # v0.7.x
helm version --short    # v3.x.x (optional)
task --version          # Task 3.x.x (optional)

# Smoke-test the platform CLI:
cd /path/to/idp-concept/projects/erp_back/pre_releases/manifests/dev/factory
koncept validate        # ✅ Configuration is valid

# Run the framework test suite:
cd /path/to/idp-concept/framework
kcl test ./...          # PASS: 243/243
```

---

## Summary: Which Install Method to Choose

| Scenario | Recommended Method |
|---|---|
| **Solo developer, one machine** | User-local binary (`~/.local/bin`) — simple, no root |
| **Team project, version consistency** | mise with `.mise.toml` committed to repo |
| **Shared server / CI agent** | System-wide via package manager or official script |
| **Docker-based dev environment** | Use the pinned `koncept` CI image (`make docker`) which bundles the kcl toolchain |

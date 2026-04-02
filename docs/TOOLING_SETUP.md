# Tooling Setup

> Complete guide to installing all tools required for **idp-concept** development.
> Covers local (user-scoped) vs global (system-wide) installation — with pros and cons for each.

---

## Tool Inventory

| Tool | Used For | Required? | Version Needed |
|---|---|---|---|
| **Nushell** (`nu`) | Runs `koncept` and `koncepttask` CLI scripts | **REQUIRED** | v0.90+ |
| **KCL** (`kcl`) | Compiles and renders KCL configs; runs tests | **REQUIRED** | v0.11+ |
| **kubeconform** | Validates rendered K8s manifests against schemas | Recommended | Latest |
| **Helm** (`helm`) | Lints and templates Helm charts | Recommended | v3+ |
| **go-task** (`task`) | Task runner used by `koncepttask` | Optional | v3+ |
| **helmfile** | Manages Helmfile deployments | Optional | v0.169+ |
| **kubectl** | Interacts with live Kubernetes clusters | Optional | v1.28+ |

> **Currently installed on this machine** (Ubuntu 24.04): KCL, kubeconform, Helm.
> **Missing**: Nushell, go-task, helmfile.

---

## TL;DR — Quick Install (Ubuntu 24.04)

Install everything you need for this project without root access, into your user account:

```bash
# 1. Nushell — install pre-built binary to ~/.local/bin (no root needed)
mkdir -p ~/.local/bin
NU_VERSION="0.104.1"   # update to latest from https://github.com/nushell/nushell/releases
curl -fsSL "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
  | tar -xz --strip-components=1 -C ~/.local/bin "nu-${NU_VERSION}-x86_64-unknown-linux-gnu/nu"
chmod +x ~/.local/bin/nu

# 2. KCL — official install script (installs to /usr/local/bin, needs sudo)
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

# 4. go-task — optional, for koncepttask
TASK_VERSION="v3.43.3"
curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.tar.gz" \
  | tar -xz -C ~/.local/bin task

# Make sure ~/.local/bin is in your PATH (usually already set on Ubuntu 24.04)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
nu --version && kcl version && kubeconform -v && task --version
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
| No system-wide installation needed | Shebang `#!/usr/bin/env nu` still requires PATH setup |
| Automatic version switching when entering project dir | Not all tools have mise plugins (nushell support via `ubi`) |

**When to use**: Team projects where tool version consistency matters; prevents "works on my machine" issues.

**mise does NOT isolate binaries inside the project folder** — it manages versioned installs in a shared cache (`~/.local/share/mise/`) and activates them per-directory. The key benefit is automatic version pinning, not isolation.

---

## Nushell

**Why**: The `koncept` and `koncepttask` CLI scripts have `#!/usr/bin/env nu` as their shebang line. Without `nu` on your `PATH`, these scripts cannot run.

**Can it be project-local?** `#!/usr/bin/env nu` means `nu` must be on `$PATH`. You can control which version is active per project (via mise), but the binary must be findable in `PATH`.

### Install: User-Local (Recommended — no root)

```bash
# Check latest version: https://github.com/nushell/nushell/releases
NU_VERSION="0.104.1"
mkdir -p ~/.local/bin
curl -fsSL "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
  | tar -xz --strip-components=1 -C ~/.local/bin "nu-${NU_VERSION}-x86_64-unknown-linux-gnu/nu"
chmod +x ~/.local/bin/nu
nu --version     # Should print: 0.104.1
```

### Install: System-Wide via apt (Ubuntu/Debian — clean, signed)

Official GPG-signed apt repository — recommended for system-wide installs:

```bash
# Add the official Nushell apt repo (GPG-signed via Gemfury)
wget -qO- https://apt.fury.io/nushell/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/fury-nushell.gpg
echo "deb [signed-by=/etc/apt/keyrings/fury-nushell.gpg] https://apt.fury.io/nushell/ /" \
  | sudo tee /etc/apt/sources.list.d/fury-nushell.list
sudo apt update && sudo apt install nushell
nu --version
```

### Install: Via mise (version-pinned per project)

```bash
# Install mise first (user-local, no root):
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Add to project .mise.toml (or .tool-versions):
cat >> /path/to/idp-concept/.mise.toml << 'EOF'
[tools]
nushell = "0.104.1"   # pin exact version
EOF

# Inside the project directory:
cd /path/to/idp-concept
mise install          # downloads and installs nu 0.104.1
nu --version          # 0.104.1 (active only in this project dir)
```

### Using Nushell Daily (Making it Your Default Shell)

Since Nushell is a full interactive shell, you may want it as your day-to-day shell:

```bash
# Add to /etc/shells (requires sudo)
which nu | sudo tee -a /etc/shells

# Change your default shell:
chsh -s $(which nu)
# Re-login to apply

# Or: launch nu from bash by just typing:
nu
```

**Pros of using Nushell daily**:
- Native compatibility — no context switching between `bash` for daily use and `nu` for running scripts
- Same language you use to write `koncept` scripts
- Structured data output (tables, records) makes working with YAML/JSON/CSV natural
- Excellent autocompletion and history

**Cons of using Nushell daily**:
- Not POSIX-compatible — bash/sh scripts must still be run with `bash script.sh` (Nushell doesn't run `.sh` files by default; use `bash` prefix)
- Some CLI tools assume bash syntax for config (e.g., `.bashrc` sourcing patterns)
- Learning curve for someone coming from bash

**Verdict**: Nushell is a production-quality shell since v0.90 and is safe for daily use. Many developers use it as their primary shell. Start with it in a separate terminal tab before committing to `chsh`.

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

**Why**: Task runner used by `koncepttask`. Not required if you only use `koncept` directly.

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
nushell       = "0.104.1"
kcl           = "0.11.0"
# kubeconform is available via the 'ubi' plugin
# helm via 'helm' plugin (mise has native helm support on some distros)

[env]
# Ensure project-local tools are on PATH when in this directory
PATH = "{{env.PATH}}"
```

> **Note**: mise's nushell support uses the `ubi` (Universal Binary Installer) backend — verify support with `mise plugins ls-remote | grep nushell` before relying on it in CI.

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
nu --version            # 0.104.1 (or higher)
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
| **Try Nushell as daily shell** | Start with user-local install; run `nu` from bash; `chsh` when comfortable |
| **Docker-based dev environment** | Use Nushell Docker image as base: `ghcr.io/nushell/nushell:latest-bookworm` |

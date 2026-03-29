---
description: "Use when working with KCL imports, kcl.mod files, module resolution, dependency paths, or debugging 'cannot find module' errors. Covers the Go-like module system KCL uses."
applyTo: "**/kcl.mod"
---

# KCL Module System — Import & Dependency Resolution

KCL's module system works similarly to Go modules. Understanding it is critical for this project.

## How kcl.mod Works

Every KCL package has a `kcl.mod` file (TOML format) that declares:
- `[package]` — name, edition, version
- `[dependencies]` — named dependencies with paths or registry references

```toml
[package]
name = "my_project"
edition = "v0.10.0"
version = "0.0.1"

[dependencies]
framework = { path = "../../framework" }
k8s = "1.31.2"
```

## Import Resolution Rules

1. **Package name = import root.** If `kcl.mod` says `name = "video_streaming"`, then `import video_streaming.kernel.project_def` resolves to `<kcl.mod dir>/kernel/project_def.k`.

2. **Dependencies = additional import roots.** If `kcl.mod` declares `framework = { path = "../../framework" }`, then `import framework.models.stack` resolves to `../../framework/models/stack.k` relative to the `kcl.mod` file.

3. **Transitive dependencies work.** If package A depends on B, and B depends on C, then A can import from C without declaring C explicitly — BUT only if B's `kcl.mod` declares C as a dependency.

4. **KCL runs from the kcl.mod directory.** The `kcl run` command resolves all paths relative to the directory containing the `kcl.mod` being executed.

5. **Registry deps (like `k8s = "1.31.2"`) are downloaded** to a global cache at `~/.kcl/kpm/` and resolved automatically.

## The Transitive Dependency Pattern (CRITICAL)

In this project, nested packages (e.g., `pre_releases/`) use transitive resolution:

```
erp_back/kcl.mod          → depends on: framework, k8s
erp_back/pre_releases/kcl.mod → depends on: erp_back (ONLY)
```

The `pre_releases/` package can `import framework.models.stack` because:
- `pre_releases` depends on `erp_back`
- `erp_back` depends on `framework`
- KCL resolves `framework` transitively through `erp_back`

### WRONG — Do NOT add direct framework dependency in nested packages:
```toml
# pre_releases/kcl.mod — WRONG
[dependencies]
erp_back = { path = "../" }
framework = { path = "../../../framework" }  # ← CAUSES PATH RESOLUTION ERRORS
```

### CORRECT — Let it resolve transitively:
```toml
# pre_releases/kcl.mod — CORRECT
[dependencies]
erp_back = { path = "../" }
# framework resolves through erp_back → framework
```

## Dependency Path Rules

- Paths are **relative to the kcl.mod file** that declares them
- Use `../` to go up directories
- The path points to the directory containing the dependency's `kcl.mod`
- Path separators are always `/` (even on Windows)

## This Project's Dependency Graph

```
k8s (registry: "1.31.2")
  ↑
framework/kcl.mod  (depends on: k8s)
  ↑
projects/<name>/kcl.mod  (depends on: framework, k8s)
  ↑
projects/<name>/pre_releases/kcl.mod  (depends on: <project> ONLY)
```

### video_streaming Pattern (older, explicit deps in sub-packages)
```
video_streaming/kcl.mod → framework, k8s
video_streaming/kernel/kcl.mod → framework, video_streaming
video_streaming/stacks/kcl.mod → framework, video_streaming
video_streaming/sites/kcl.mod → framework, tenants, video_streaming
video_streaming/pre_releases/kcl.mod → framework, video_streaming
video_streaming/releases/kcl.mod → framework, kernel, sites, stacks, tenants, core_sources
```

### erp_back Pattern (newer, minimal deps via transitive resolution)
```
erp_back/kcl.mod → framework, k8s
erp_back/pre_releases/kcl.mod → erp_back (ONLY)
```

The erp_back pattern is **simpler and recommended** for new projects.

## Common Errors and Fixes

### "cannot find the module" / "cannot find the package"
- Check that the dependency is declared in kcl.mod OR is reachable transitively
- Verify the path is correct relative to the kcl.mod file
- Run `kcl run` from the directory containing the kcl.mod

### Lock file shows wrong package name (e.g., `vPkg_UUID` instead of `framework_0.0.1`)
- This indicates path resolution failure
- Remove the lock file and fix the kcl.mod dependency paths
- Use transitive resolution instead of direct paths for nested packages

### Relative path resolves to wrong location
- KCL resolves paths from the kcl.mod location, not from the file being compiled
- Double-check by counting `../` steps from kcl.mod to the target directory

## Internal Import Syntax

Within a package, imports use the **package name as root**:

```kcl
# In a file inside the "framework" package:
import models.stack        # resolves to framework/models/stack.k (relative to own package)
import procedures.helper   # resolves to framework/procedures/helper.k

# In a file inside the "video_streaming" package:
import video_streaming.kernel.project_def    # resolves from video_streaming root
import framework.models.release              # resolves from framework dependency
```

Note: within a package, you can omit the package name prefix for sibling imports:
```kcl
# In framework/models/release.k:
import models.stack    # Same as import framework.models.stack (within own package)
import procedures.kcl_to_kusion  # Same as import framework.procedures.kcl_to_kusion
```

## Relative Imports (within same directory)

Use `.` prefix for imports from the same directory:

```kcl
# In pre_releases/gitops/dev/factory/yaml_builder.k:
import .factory_seed    # imports factory_seed.k from same directory
```

---
description: Debug KCL compilation errors, import resolution failures, and module system issues
---

# Debug KCL Error

You are helping debug a KCL compilation error in idp-concept.

## Context Files
- #file:.github/instructions/kcl-module-system.instructions.md
- #file:.github/docs/AI_REFERENCE.md

## Common Issues

### 1. "type redefinition" or reserved word error
**Cause**: Used `type` as a field name in Kubernetes manifests.
**Fix**: Replace `type = "NodePort"` with `$type = "NodePort"`.
This applies to: Service.spec.type, PV labels.type, Kafka listener.type, Strategy.type, Storage.type.

### 2. "attribute not found in schema"
**Cause**: Accessing a field that doesn't exist or is misspelled.
**Fix**: Check the schema definition. Use `?` for optional access.

### 3. "Cannot find module" / "cannot find the package"
**Cause**: Import path doesn't match `kcl.mod` dependencies.
**Fix**:
- Check that the dependency is declared in `kcl.mod` OR reachable transitively
- Verify the path is correct **relative to the kcl.mod file** (NOT the source file)
- For nested packages (pre_releases/): depend ONLY on the parent project, NOT framework directly
- Run `kcl run` from the directory containing the `kcl.mod`

**Critical pattern for pre_releases/kcl.mod:**
```toml
# CORRECT — framework resolves transitively through the project
[dependencies]
erp_back = { path = "../" }

# WRONG — causes path resolution errors
[dependencies]
erp_back = { path = "../" }
framework = { path = "../../../framework" }  # DO NOT ADD THIS
```

### 4. "type mismatch" when using union operator
**Cause**: Merging incompatible types with `|`.
**Fix**: Ensure both sides use the same schema type.

### 5. Missing `.instance` causing wrong type
**Cause**: Passing a `Project` instead of `ProjectInstance` to Release.
**Fix**: Use `my_project.instance` not `my_project`.

### 6. Undefined vs None
**Cause**: Using Python `None` instead of KCL `Undefined`.
**Fix**: Check with `is Undefined` not `== None`.

### 7. Lock file shows wrong package name (e.g., `vPkg_UUID`)
**Cause**: kcl.mod has incorrect dependency paths causing metadata resolution failure.
**Fix**: Remove the lock file, fix paths in kcl.mod, re-run `kcl run`.

### 8. Relative path resolves to wrong location
**Cause**: Paths in kcl.mod are relative to the kcl.mod itself, not the source file.
**Fix**: Count `../` steps from the kcl.mod file to the target directory.

## Debugging Steps
1. Read the full error message — identify the file and line
2. Check the schema definition that's referenced
3. Look for the common mistakes above
4. Check `kcl.mod` for dependency resolution — are paths correct relative to kcl.mod location?
5. For import errors: trace the dependency chain (package → dependency → transitive)
6. Run `kcl run <file>` from the directory with the kcl.mod
7. If lock file exists and looks corrupt, delete it and re-run

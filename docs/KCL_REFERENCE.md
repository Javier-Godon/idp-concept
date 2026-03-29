# KCL Quick Reference for idp-concept

> This document is optimized for both human developers and AI coding assistants.
> Reference: https://www.kcl-lang.io/docs/

---

## 1. Language Basics

### Variable Declaration
```kcl
# Public variable (exported to output)
myVar = "hello"

# Private variable (NOT exported)
_privateVar = "internal only"
```

### Types
```kcl
name: str                      # String
count: int                     # Integer
enabled: bool                  # Boolean
ratio: float                   # Float
items: [str]                   # List of strings
labels: {str: str}             # Dict with string keys and values
anything: any                  # Any type
optional_field?: str           # Optional (can be omitted)
default_field: str = "default" # Default value
```

### String Interpolation
```kcl
name = "world"
greeting = "hello ${name}"              # → "hello world"
image = "${asset.image}:${asset.version}" # → "ghcr.io/org/app:v1.0"
```

### Raw Strings (No Interpolation)
```kcl
raw = r"""
This ${is} not interpolated
Useful for YAML/JSON embedded content
"""
```

---

## 2. Schemas

### Basic Schema
```kcl
schema Person:
    name: str
    age: int
    email?: str  # optional

# Instantiation
p = Person {
    name = "Alice"
    age = 30
}
```

### Schema Inheritance
```kcl
schema Animal:
    name: str
    sound: str

schema Dog(Animal):
    sound = "woof"  # default override
    breed: str
```

### Schema with Validation
```kcl
schema Port:
    port: int
    check:
        0 < port < 65536, "port must be between 1 and 65535"
```

### Enum-like Constraints
```kcl
schema Component:
    kind: "APPLICATION" | "INFRASTRUCTURE"
```

---

## 3. The Instance Pattern (idp-concept specific)

This project uses a dual Schema + Instance pattern throughout:

```kcl
# Instance: flat data container (what gets passed around)
schema ProjectInstance:
    name: str
    description: str
    configurations: any

# Schema: validated constructor with auto-instance
schema Project:
    instance: ProjectInstance = ProjectInstance {
        name = name
        description = description
        configurations = configurations
    }
    name: str
    description: str
    configurations: any
```

**Usage:**
```kcl
my_project = Project {
    name = "My App"
    description = "..."
    configurations = my_configs
}

# Pass the flat instance downstream
release = Release {
    project = my_project.instance  # ← .instance here
}
```

---

## 4. Union Operator (`|`) for Config Merging

### Basic Merging
```kcl
base = {a = 1, b = 2}
override = {b = 3, c = 4}
merged = base | override  # → {a = 1, b = 3, c = 4}
```

### Schema Merging (idp-concept pattern)
```kcl
merge_configurations = lambda kernel, profile, tenant, site -> VideoStreamingConfigurations {
    _configs = kernel
    _configs = _configs | profile   # profile overrides kernel
    _configs = _configs | tenant    # tenant overrides profile
    _configs = _configs | site      # site overrides tenant
}
```

---

## 5. Lambda Functions

```kcl
# Simple lambda
add = lambda x: int, y: int -> int {
    x + y
}

# Lambda with complex return
extract = lambda models: [any], name: str -> [any] {
    [model for model in models if model.name == name]
}
```

---

## 6. List Comprehensions

```kcl
# Filter
adults = [p for p in people if p.age >= 18]

# Transform
names = [p.name for p in people]

# Nested (used in Kusion spec generation)
all_manifests = [manifest for component in components for manifest in component.manifests]
```

---

## 7. Conditional Expressions

```kcl
# Ternary
result = "yes" if condition else "no"

# Conditional in schema
schema Resource:
    id: str = "${manifest.apiVersion}:${manifest.kind}:${manifest.metadata.name}" \
        if manifest.metadata.namespace is Undefined \
        else "${manifest.apiVersion}:${manifest.kind}:${manifest.metadata.namespace}:${manifest.metadata.name}"
```

---

## 8. `$type` Escape (CRITICAL)

KCL reserves the word `type`. For Kubernetes fields named `type`, use `$type`:

```kcl
# WRONG — KCL will error
spec = {
    type = "NodePort"  # ERROR: 'type' is reserved
}

# CORRECT
spec = {
    $type = "NodePort"  # Outputs as 'type: NodePort' in YAML
}
```

**Affected K8s resources:**
- `Service.spec.type` → `$type = "NodePort" | "ClusterIP" | "LoadBalancer"`
- `PersistentVolume.metadata.labels.type` → `$type = "local"`
- `Kafka listener.type` → `$type = "internal" | "nodeport"`
- `Strategy.type` → `$type = "RollingUpdate"`
- `JBOD storage.type` → `$type = "jbod"` / `$type = "persistent-claim"`

---

## 9. CLI Parameters with `option()`

```kcl
# In .k file
chart_name = option("chart")

# CLI invocation
# kcl run builder.k -D chart="my-chart"
```

---

## 10. Built-in `manifests` Module

```kcl
import manifests

# Serialize to multi-document YAML stream
manifests.yaml_stream([deployment, service, configmap])

# Also works with nested lists
manifests.yaml_stream([[deployment, service], [configmap]])
```

---

## 11. `Undefined` Check

```kcl
# Check if a field is not set
if manifest.metadata.namespace is Undefined:
    id = "${manifest.apiVersion}:${manifest.kind}:${manifest.metadata.name}"
```

---

## 12. `kcl.mod` — Package Declaration

```toml
[package]
name = "my_package"
edition = "v0.10.0"
version = "0.0.1"

[dependencies]
framework = { path = "../../framework" }  # Local dependency
k8s = "1.31.2"                            # Registry dependency
```

### Import Resolution
```kcl
# Imports resolve relative to kcl.mod
import framework.models.project        # From framework dependency
import video_streaming.kernel.project_def  # From video_streaming dependency
import k8s.api.core.v1 as core         # From k8s registry package
import k8s.api.apps.v1 as apps         # From k8s registry package
```

---

## 13. Common Mistakes (AI Hints)

| Mistake | Correct Pattern |
|---|---|
| Using `type` in K8s specs | Use `$type` |
| Forgetting `.instance` when passing to Release | `my_project.instance` not `my_project` |
| Using `=` in schema type hints | Use `:` for type hints: `name: str`, `=` for values: `name = "foo"` |
| Python-style f-strings | Use `${var}` for KCL interpolation, not `{var}` or `f"{var}"` |
| Missing trailing comma in lists | KCL lists don't need commas between items in many cases |
| Using `None` | KCL uses `Undefined`, not `None` or `null` |
| Using `True/False` in schema | KCL uses `True`/`False` (Python-like, capitalized) |
| Forgetting `import manifests` | Required for `manifests.yaml_stream()` |
| Using `self` or `this` | KCL schemas don't use `self` — fields are accessed directly by name |

---

## 14. KCL CLI Commands

```bash
# Run a KCL file
kcl run main.k

# Run with output to file
kcl run main.k -o output.yaml

# Run with CLI parameters
kcl run builder.k -D chart="my-chart" -D version="1.0"

# Import CRDs to KCL schemas
kcl import -m crd -s crd.yaml

# Format KCL files
kcl fmt main.k

# Lint KCL files
kcl lint main.k

# Test KCL files
kcl test
```

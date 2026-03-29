---
name: kcl-language
description: "KCL language patterns, syntax, and idioms for idp-concept. Use when writing KCL code, fixing KCL errors, creating schemas, working with lambdas, or understanding KCL language features like union operators, comprehensions, and type system."
---

# KCL Language Skill for idp-concept

## When to Use
- Writing or modifying any `.k` file
- Debugging KCL compilation errors
- Creating schemas, lambdas, or configuration files
- Understanding KCL-specific patterns used in this project

## Quick Syntax Reference

### Variables & Types
```kcl
# Immutable by default — no let/const keyword needed
name = "hello"
count = 42
enabled = True
items = ["a", "b", "c"]
config = { key = "value", nested = { inner = 1 } }

# Type annotations (optional but recommended in schemas)
name: str = "hello"
count: int = 42
items: [str] = ["a", "b"]
config: {str:str} = { key = "value" }
```

### Private Variables
```kcl
# Prefix with _ to prevent export to output
_internal = "not exported"
public = "exported to YAML"
```

### String Interpolation
```kcl
name = "world"
greeting = "hello ${name}"           # → "hello world"
url = "http://${host}:${port}/api"   # → "http://localhost:8080/api"
```

### Conditional Expressions
```kcl
# Inline conditional
value = "yes" if condition else "no"

# Block conditional (in schema/dict context)
config = {
    if enabled:
        feature = "on"
    if not disabled:
        extra = "included"
}
```

### Schemas
```kcl
schema Person:
    name: str                    # Required
    age?: int                    # Optional (? suffix)
    email?: str = "none"         # Optional with default
    tags: [str] = []             # Required with default

    check:
        age > 0 if age, "age must be positive"
```

### Schema Inheritance
```kcl
schema Animal:
    name: str
    sound: str

schema Dog(Animal):
    sound = "woof"               # Override parent default
    breed?: str                  # Add new field
```

### Schema Instantiation
```kcl
dog = Dog {
    name = "Rex"
    breed = "Labrador"
}
```

### Lambda Functions
```kcl
add = lambda x: int, y: int -> int {
    x + y
}
result = add(1, 2)   # → 3

# Lambda returning a complex type
build_config = lambda name: str, port: int -> any {
    { name = name, port = port, enabled = True }
}
```

### List Comprehensions
```kcl
numbers = [1, 2, 3, 4, 5]
doubled = [n * 2 for n in numbers]              # → [2, 4, 6, 8, 10]
evens = [n for n in numbers if n % 2 == 0]      # → [2, 4]
```

### Dict Comprehensions
```kcl
items = {k: v for k, v in {a = 1, b = 2}}
```

### Union Operator (|) — Config Merging
```kcl
base = { a = 1, b = 2 }
override = { b = 3, c = 4 }
merged = base | override    # → { a = 1, b = 3, c = 4 }
# Later value wins for overlapping keys
```

### Undefined
```kcl
# Undefined is KCL's "absent" value — stripped from output
optional_field = Undefined   # Field won't appear in YAML
# Check with:
if value is not Undefined:
    do_something()
```

## Patterns Specific to This Project

### The Schema + Instance Pattern
Every framework model has a Schema (validates + constructs) and an Instance (flat data):
```kcl
schema Component:
    instance: ComponentInstance = ComponentInstance {
        name = name
        kind = kind
        # ... auto-populates from schema fields
    }
    name: str
    kind: str
    # ...
```

Always pass `.instance` downstream:
```kcl
_my_module = MyModule { name = "app", ... }.instance   # ✅
_my_module = MyModule { name = "app", ... }             # ❌ Wrong type
```

### The `$type` Escape
`type` is a reserved word in KCL. For K8s fields that use `type`:
```kcl
spec = {
    $type = "ClusterIP"     # Renders as "type: ClusterIP" in YAML
}
labels = {
    $type = "local"         # Renders as "type: local" in YAML
}
```

### The `option()` Function
Read CLI arguments passed with `-D`:
```kcl
env = option("environment")   # kcl run -D environment=prod
```

### YAML Stream Output
```kcl
import manifests
# Outputs multiple YAML docs separated by ---
manifests.yaml_stream([resource1, resource2, resource3])
```

### File Reading
```kcl
import yaml
import file
data = yaml.decode(file.read("config.yaml"))
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Using `type` in K8s manifests | Use `$type` |
| Passing schema instead of `.instance` | Add `.instance` |
| Using `None` for absent values | Use `Undefined` |
| Mutable variable reassignment | KCL variables are immutable; use union `|` for merging |
| Missing `?` on optional schema fields | Add `?` suffix: `field?: str` |
| String interpolation with `${}` in wrong context | Only works in `"double quoted"` strings |

## Reference Files
- [KCL import system](./../../instructions/kcl-module-system.instructions.md)
- [Framework builders](./../../instructions/framework-builders.instructions.md)
- [Official KCL docs](https://www.kcl-lang.io/docs/)

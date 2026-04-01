# Nushell Quick Reference for idp-concept

> This document covers Nushell syntax and patterns as used in the `platform_cli/` scripts.
> Reference: https://www.nushell.sh/book/

---

## 1. Script Structure

Nushell scripts use `#!/usr/bin/env nu` as the shebang line.

```nu
#!/usr/bin/env nu

def main [
  command: string         # Positional parameter with type
  render_type: string     # Another positional parameter
  --factory: string       # Optional named flag
  --output: string        # Another optional flag
] {
  # Function body
}
```

### Key Differences from Bash
- **Typed parameters**: Every parameter has a type
- **Structured data**: Everything is tables/records, not text
- **No `$()` subshells**: Use `()` for expressions
- **No unquoted variable expansion**: Variables are always `$var`

---

## 2. Variables

```nu
# Immutable (default)
let name = "hello"

# Mutable
mut counter = 0
$counter = $counter + 1

# Environment variables
$env.PWD           # Current working directory
$env.FILE_PWD      # Directory where the script file lives
$env.HOME          # Home directory
```

---

## 3. String Interpolation

**This is the most common AI mistake with Nushell!**

```nu
# CORRECT Nushell interpolation
let name = "world"
print $"Hello ($name)"           # → Hello world
print $"Path: ($env.PWD)"        # → Path: /home/user/project

# With expressions
print $"Sum: (1 + 2)"            # → Sum: 3
print $"Upper: ($name | str upcase)" # → Upper: WORLD

# WRONG — these are NOT Nushell syntax
print "Hello ${name}"            # ← This is bash/KCL, NOT Nushell
print f"Hello {name}"            # ← This is Python, NOT Nushell
```

**Pattern**: `$"text (expression) more text"` — dollar sign before the quote, parentheses around expressions.

---

## 4. Path Operations

```nu
# Get basename (last component)
"/home/user/project/dev" | path basename     # → "dev"

# Get dirname (parent directory)
"/home/user/project/dev" | path dirname      # → "/home/user/project"

# Expand relative to absolute
"./factory" | path expand                    # → "/full/path/to/factory"

# Join paths
$koncept_dir | path join "taskfiles/argocd/taskfile.yaml"
```

---

## 5. Control Flow

### Match Expression
```nu
match $render_type {
  "argocd" => {
    print "[ArgoCD] Generating manifests..."
    kcl run $"($factory_dir)/kubernetes_manifests_builder.k" -o $manifest_path
  }
  "helmfile" => {
    print "[Helmfile] Generating chart..."
  }
  _ => {           # Default/wildcard
    print $"Unsupported: ($render_type)"
    exit 1
  }
}
```

### If/Else
```nu
let factory_dir = (if $factory != null { $factory } else { "factory" })
```

### For Loop
```nu
for item in $items {
  print $"Processing ($item)"
}
```

---

## 6. External Commands

Prefix external commands with `^` to distinguish from Nushell built-ins:

```nu
^task generate:all            # Run go-task
^kcl run main.k               # Run KCL compiler
^mkdir -p output               # Can also use Nushell's mkdir
```

**Note**: `kcl`, `task`, `mkdir` without `^` may work if Nushell doesn't have a conflicting built-in, but `^` makes it explicit.

---

## 7. Null Handling

```nu
# Check if flag was provided
if $factory != null { $factory } else { "factory" }

# Nushell uses 'null' not 'None' or 'nil'
```

---

## 8. Directory Operations

```nu
mkdir $output_path             # Create directory (recursive by default)
touch $"($chart_dir)/values.yaml"  # Create empty file
```

---

## 9. Pipes and Structured Data

Nushell pipes structured data (tables, records), not text:

```nu
# List files and filter
ls | where size > 1kb | sort-by modified

# Parse and process
open config.yaml | get server.port
```

---

## 10. The `koncept` Script Explained

```nu
#!/usr/bin/env nu

def main [
  command: string        # "render"
  render_type: string    # "argocd" | "helmfile" | "kusion"
  --factory: string      # factory directory (default: "factory")
  --output: string       # output directory
] {
  let cwd = $env.PWD                        # Current working directory
  let base = ($cwd | path basename)          # e.g., "dev"
  let app = ($cwd | path dirname | path basename)  # e.g., "my-app"
  let koncept_dir = ($env.FILE_PWD)          # Where koncept script lives

  # Default factory to "factory" if not specified
  let factory_dir = (if $factory != null { $factory } else { "factory" })

  if $command != "render" {
    print "Unknown command: $command"
    exit 1
  }

  match $render_type {
    "argocd" => {
      # Output: ../../../generated/<env>/<app>/kubernetes_manifests.yaml
      let output_dir = (if $output != null { $output } else { $"../../../generated/($base)/($app)" })
      let output_path = ($output_dir | path expand)
      let manifest_path = $"($output_path)/kubernetes_manifests.yaml"
      mkdir $output_path
      kcl run $"($factory_dir)/kubernetes_manifests_builder.k" -o $manifest_path
    }
    "helmfile" => {
      # Output: output/charts/<name>/{Chart.yaml,values.yaml,templates/manifests.yaml}
      #         output/helmfile.yaml
      let output_dir = (if $output != null { $output } else { "output" })
      let chart_dir = $"($output_dir)/charts"
      mkdir $chart_dir
      kcl run $"($factory_dir)/chart_builder.k" -D "chart=\"default\"" -o $"($chart_dir)/Chart.yaml"
      touch $"($chart_dir)/values.yaml"
      let templates_dir = $"($chart_dir)/templates"
      mkdir $templates_dir
      kcl run $"($factory_dir)/templates_builder.k" -D "chart=\"default\"" -o $"($templates_dir)/manifests.yaml"
      kcl run $"($factory_dir)/helmfile_builder.k" -o $"($output_dir)/helmfile.yaml"
    }
    "kusion" => {
      # Output: output/kusion_spec.yaml
      let output_path = (if $output != null { $output } else { "output" })
      let output_file = $"($output_path)/kusion_spec.yaml"
      mkdir $output_path
      kcl run $"($factory_dir)/main.k" -o $output_file
    }
  }
}
```

---

## 11. Common Mistakes (AI Hints)

| Mistake | Correct Pattern |
|---|---|
| `${var}` for interpolation | `($var)` inside `$"..."` |
| `$(command)` for subshell | `(command)` without `$` |
| `"string $var"` | `$"string ($var)"` — need `$` prefix on quote |
| `if [ -f file ]` | `if ($file \| path exists) { }` |
| `export VAR=value` | `$env.VAR = "value"` |
| `echo "text"` | `print "text"` (echo works but print is idiomatic) |
| `command arg1 arg2` without `^` | `^command arg1 arg2` for external programs |
| `null` check with `== null` | `!= null` or `== null` both work |

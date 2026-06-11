# Developer Documentation

Start here if you build or operate applications through the platform without changing the framework internals.
The supported interface is the `koncept` CLI. Install, update, and uninstall
instructions live in [CLI_DISTRIBUTION.md](../operations/CLI_DISTRIBUTION.md).

## Read In Order

1. [DEVELOPER_QUICKSTART.md](DEVELOPER_QUICKSTART.md) — first validate/render loop.
2. [CLI_REFERENCE.md](CLI_REFERENCE.md) — current `koncept` commands and flags.
3. [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) — how projects, factories, stacks, and templates fit together.
4. [WORKFLOWS.md](WORKFLOWS.md) — role-based recipes for common tasks.

## Reference

| Document | Use |
|---|---|
| [APPLICATION_CONFIGURATION_PATTERNS.md](APPLICATION_CONFIGURATION_PATTERNS.md) | Standard configuration and environment-variable patterns |
| [WINDOWS_LOCAL_SETUP.md](WINDOWS_LOCAL_SETUP.md) | Windows/WSL2 local setup |

## Common Tasks

| Task | Start with |
|---|---|
| Install, update, or uninstall `koncept` | [../operations/CLI_DISTRIBUTION.md](../operations/CLI_DISTRIBUTION.md) |
| Install local supporting tools | [../operations/TOOLING_SETUP.md](../operations/TOOLING_SETUP.md) |
| Create a new project | [CLI_REFERENCE.md](CLI_REFERENCE.md#koncept-init-project) |
| Add a service or database | [CLI_REFERENCE.md](CLI_REFERENCE.md#koncept-init-module) |
| Render manifests | [DEVELOPER_QUICKSTART.md](DEVELOPER_QUICKSTART.md#quick-commands) |
| Troubleshoot a factory | [CLI_REFERENCE.md](CLI_REFERENCE.md#troubleshooting) |

## Before Opening A Change

Run the shortest validation loop that covers your change:

```bash
koncept doctor --factory <factory>
koncept validate --factory <factory>
koncept render argocd --factory <factory>
koncept policy check --factory <factory>
```

For framework or platform changes, add golden checks and the relevant acceptance
test group before asking for review.

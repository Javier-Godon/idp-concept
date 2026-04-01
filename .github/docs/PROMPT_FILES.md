# Copilot Prompt Files

> Prompt files (`.github/prompts/*.prompt.md`) are reusable task-specific prompts
> that appear in GitHub Copilot Chat's slash command menu.

## How to Use

In VS Code Copilot Chat, type `/` to see available prompt files, or reference them directly:

```
@workspace /new-kcl-module
```

## Available Prompts

| Prompt | File | Purpose |
|---|---|---|
| Create KCL Module | `.github/prompts/new-kcl-module.prompt.md` | Generate a new Component or Accessory module |
| Create Tenant | `.github/prompts/new-tenant.prompt.md` | Add a new tenant with configurations |
| Create Site | `.github/prompts/new-site.prompt.md` | Add a new deployment site |
| Create Release | `.github/prompts/new-release.prompt.md` | Create versioned release with factory |
| Create Stack | `.github/prompts/new-stack.prompt.md` | Define a new stack |
| Debug KCL | `.github/prompts/debug-kcl.prompt.md` | Debug KCL compilation errors |
| Crossplane Composition | `.github/prompts/crossplane-composition.prompt.md` | Create Crossplane XRD + Composition |

## Creating Custom Prompts

1. Create a new `.prompt.md` file in `.github/prompts/`
2. Include context about which files to read and what patterns to follow
3. Reference the documentation: `#file:.github/docs/KCL_REFERENCE.md`

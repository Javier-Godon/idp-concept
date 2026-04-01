---
description: Define a new stack (combination of modules for deployment)
---

# Create a New Stack

You are creating a new stack definition in idp-concept.

## Context Files
- #file:.github/docs/AI_REFERENCE.md
- #file:framework/models/stack.k
- #file:framework/assembly/helpers.k
- #file:projects/erp_back/stacks/development/stack_def.k
- #file:projects/erp_back/stacks/development/profile_configurations.k
- #file:projects/erp_back/stacks/development/profile_def.k
- #file:projects/video_streaming/stacks/development/stack_def.k

## Rules
1. Stacks go under `stacks/development/` (for dev) or `stacks/versioned/<version>/base/`
2. Create three files:
   - `profile_configurations.k` — Profile-specific configuration overrides
   - `profile_def.k` — Profile instance
   - `stack_def.k` — Stack schema extending `stack.Stack`
3. The stack schema MUST:
   - Extend `stack.Stack` via inheritance
   - Define `k8snamespaces`, `components`, `accessories` arrays
   - Use `instanceConfigurations` to get merged configs
4. Use assembly helpers for namespace creation (recommended):
   ```kcl
   import framework.assembly.helpers as asm
   _apps_ns = asm.create_namespace(instanceConfigurations.appsNamespace, instanceConfigurations)
   ```
5. Each module instantiation MUST:
   - Call `.instance` to get the flat instance
   - Set `dependsOn` referencing namespace instances
   - Pass `configurations = instanceConfigurations`

## Ask the user
- Stack name (development, staging, or version like v1_0_0)
- Which modules to include (components and accessories)
- Which namespaces to create
- Profile configuration overrides

---
description: Add a new tenant with configuration overrides
---

# Create a New Tenant

You are adding a new tenant to a project in idp-concept.

## Context Files
- #file:docs/FRAMEWORK_SCHEMAS.md
- #file:projects/video_streaming/tenants/germany/tenant_def.k
- #file:projects/video_streaming/tenants/germany/germany_configurations.k
- #file:projects/video_streaming/tenants/vendor/tenant_def.k
- #file:projects/video_streaming/tenants/vendor/tenant_configurations.k

## Rules
1. Create a folder under the project's `tenants/` directory named after the tenant (lowercase)
2. Create `tenant_def.k` with:
   ```kcl
   import framework.models.tenant
   tenant_<name> = tenant.Tenant { name = "...", description = "...", configurations = _<name>_tenant_configurations }
   ```
3. Create `<name>_configurations.k` (or `tenant_configurations.k`) with a private variable `_<name>_tenant_configurations` typed to the project's configuration schema
4. Import the project's `video_streaming_configurations.VideoStreamingConfigurations` (or equivalent)
5. Only override fields that differ for this tenant (the merge function handles defaults)

## Ask the user
- Tenant name and description
- Which project this tenant belongs to
- What configuration overrides are needed (brandIcon, namespaces, etc.)

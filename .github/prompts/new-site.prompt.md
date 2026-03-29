---
description: Add a new deployment site (target environment)
---

# Create a New Site

You are adding a new deployment site/environment to a project in idp-concept.

## Context Files
- #file:docs/FRAMEWORK_SCHEMAS.md
- #file:docs/DEVELOPMENT_WORKFLOWS.md
- #file:projects/video_streaming/sites/development/dev_cluster/site_def.k
- #file:projects/video_streaming/sites/development/dev_cluster/configurations.k
- #file:projects/video_streaming/sites/tenants/production/berlin/site_def.k
- #file:projects/video_streaming/sites/tenants/production/berlin/configurations.k

## Rules
1. Sites go under `sites/development/` (for dev/staging) or `sites/tenants/<env>/<city>/` (for tenant sites)
2. Create `site_def.k` with:
   ```kcl
   import framework.models.site
   <name>_site = site.Site { name = "...", tenant = <tenant_ref>, configurations = VideoStreamingConfigurations { **configurations._<name>_site_configurations } }
   ```
3. Create `configurations.k` with a private `_<name>_site_configurations` variable
4. Optionally create `config.yaml` for YAML-based config (loaded via `yaml.decode(file.read(...))`)
5. The site MUST reference a tenant
6. Only override fields that differ per site (siteName, rootPaths, etc.)

## Ask the user
- Site name (city/cluster name)
- Which tenant owns this site
- Environment type (development, pre-production, production)
- Configuration overrides (rootPaths, endpoints, etc.)

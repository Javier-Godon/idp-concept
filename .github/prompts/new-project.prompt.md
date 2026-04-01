---
description: "Create a new project from scratch using framework templates (WebAppModule, SingleDatabaseModule, KafkaClusterModule)"
argument-hint: "Project name and what it deploys (e.g., 'e-commerce with API, Postgres, and Redis')"
---

# Create a New Project

You are scaffolding a complete new project for idp-concept using the recommended template approach.

## Context Files
- #file:.github/docs/AI_REFERENCE.md
- #file:.github/instructions/kcl-module-system.instructions.md
- #file:projects/erp_back/kcl.mod
- #file:projects/erp_back/core_sources/erp_back_configurations.k
- #file:projects/erp_back/core_sources/merge_configurations.k
- #file:projects/erp_back/kernel/project_def.k
- #file:projects/erp_back/kernel/configurations.k
- #file:projects/erp_back/modules/appops/erp_api/erp_api_module_def.k
- #file:projects/erp_back/modules/infrastructure/postgres/postgres_module_def.k
- #file:projects/erp_back/stacks/development/stack_def.k
- #file:projects/erp_back/stacks/development/profile_def.k
- #file:projects/erp_back/stacks/development/profile_configurations.k
- #file:projects/erp_back/pre_releases/kcl.mod
- #file:projects/erp_back/pre_releases/manifests/dev/factory/factory_seed.k
- #file:projects/erp_back/pre_releases/manifests/dev/factory/yaml_builder.k

## Directory Structure to Create

```
projects/<project_name>/
├── kcl.mod                          # name=<project_name>, deps: framework, k8s
├── main.k                           # empty
├── core_sources/
│   ├── <project>_configurations.k   # extends BaseConfigurations
│   └── merge_configurations.k       # delegates to framework merge
├── kernel/
│   ├── configurations.k             # kernel defaults
│   └── project_def.k                # Project instance
├── modules/
│   ├── appops/<module>/             # WebAppModule templates
│   └── infrastructure/<module>/     # SingleDatabaseModule / KafkaClusterModule
├── stacks/development/
│   ├── stack_def.k                  # Stack with namespaces, components, accessories
│   ├── profile_def.k                # Profile instance
│   └── profile_configurations.k     # Dev profile config
├── tenants/
│   └── vendor/tenant_def.k          # Internal vendor tenant
├── sites/development/dev_cluster/
│   ├── site_def.k                   # Dev cluster site
│   └── configurations.k             # Dev site config
└── pre_releases/
    ├── kcl.mod                      # ONLY depends on <project_name>
    ├── configurations_dev.k         # Merge pipeline
    └── manifests/dev/factory/
        ├── factory_seed.k           # Stack + rendering setup
        └── yaml_builder.k           # YAML output
```

## Rules

1. `kcl.mod` at project root: `name = "<project_name>"`, deps on `framework` and `k8s = "1.31.2"`
2. Configuration schema MUST extend `framework.models.configurations.BaseConfigurations`
3. Merge function MUST delegate to `framework.models.configurations.merge_configurations`
4. Use `WebAppModule` for application components, `SingleDatabaseModule` for databases, `KafkaClusterModule` for Kafka
5. Stack MUST use `framework.assembly.helpers.create_namespace` for namespace creation
6. `pre_releases/kcl.mod` MUST depend ONLY on the parent project — framework resolves transitively
7. Never add `framework = { path = "..." }` in `pre_releases/kcl.mod`
8. All main.k files can be empty placeholder files
9. Pin k8s dependency version to `"1.31.2"`

## Ask the user
- Project name (lowercase with underscores)
- What application components to deploy (name, port, type)
- What infrastructure to deploy (databases, message queues)
- Any project-specific configuration fields needed

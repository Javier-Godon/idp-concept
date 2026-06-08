# Documentation Index

> The docs are organized by reader first, then by topic. Start with the role that matches what you are trying to do.

For AI-assistant references, see [../.github/docs/](../.github/docs/).

## Start By Role

### Application Developer

Use this path when you want to create, configure, validate, or render an application through the platform without changing the framework.

1. [developer/DEVELOPER_QUICKSTART.md](developer/DEVELOPER_QUICKSTART.md)
2. [developer/CLI_REFERENCE.md](developer/CLI_REFERENCE.md)
3. [developer/DEVELOPER_GUIDE.md](developer/DEVELOPER_GUIDE.md)
4. [developer/WORKFLOWS.md](developer/WORKFLOWS.md)

### Platform Engineer

Use this path when you own the platform framework, templates, installation, Backstage integration, Crossplane APIs, or team onboarding.

1. [platform-engineering/PLATFORM_INSTALLATION.md](platform-engineering/PLATFORM_INSTALLATION.md)
2. [platform-engineering/PROJECT_ARCHITECTURE.md](platform-engineering/PROJECT_ARCHITECTURE.md)
3. [platform-engineering/FRAMEWORK_SCHEMAS.md](platform-engineering/FRAMEWORK_SCHEMAS.md)
4. [platform-engineering/FRAMEWORK_EXTENSION_GUIDE.md](platform-engineering/FRAMEWORK_EXTENSION_GUIDE.md)
5. [integrations/README.md](integrations/README.md)

### Operator / Release Engineer

Use this path when you install tooling, publish artifacts, run promotion gates, or operate policy/security controls.

1. [operations/TOOLING_SETUP.md](operations/TOOLING_SETUP.md)
2. [operations/CLI_DISTRIBUTION.md](operations/CLI_DISTRIBUTION.md)
3. [operations/OPERATING_MODEL.md](operations/OPERATING_MODEL.md)
4. [operations/SECURITY.md](operations/SECURITY.md)
5. [operations/README.md](operations/README.md)

### Framework Contributor

Use this path when you change KCL framework internals, renderers, templates, builders, or acceptance fixtures.

1. [platform-engineering/PROJECT_ARCHITECTURE.md](platform-engineering/PROJECT_ARCHITECTURE.md)
2. [platform-engineering/FRAMEWORK_SCHEMAS.md](platform-engineering/FRAMEWORK_SCHEMAS.md)
3. [platform-engineering/FRAMEWORK_EXTENSION_GUIDE.md](platform-engineering/FRAMEWORK_EXTENSION_GUIDE.md)
4. [testing/TESTING_STRATEGY.md](testing/TESTING_STRATEGY.md)
5. [testing/VERIFICATION_MATRIX.md](testing/VERIFICATION_MATRIX.md)

## Folder Map

| Folder | Audience | Purpose |
|---|---|---|
| [developer/](developer/) | Application developers | CLI usage, quickstarts, workflows, and application configuration patterns |
| [platform-engineering/](platform-engineering/) | Platform engineers | Platform installation, architecture, schemas, extension, versioning, storage, migration |
| [operations/](operations/) | Operators / release engineers | Tooling install, CLI distribution, governance, security, publishing, metrics, changelog |
| [testing/](testing/) | Contributors / platform engineers | Test strategy, verification, acceptance, golden outputs, Crossplane testing |
| [integrations/](integrations/) | Platform engineers | Backstage, Crossplane, Helmfile, observability, APISIX/Superset/Power BI |
| [strategy/](strategy/) | Maintainers / stakeholders | Roadmap, assessment, adoption, comparisons, evaluations |
| [decisions/](decisions/) | All maintainers | Architecture decision records |
| [archive/](archive/) | Maintainers | Historical reports and superseded progress notes |

## High-Value Entry Points

| Need | Document |
|---|---|
| Install local tools | [operations/TOOLING_SETUP.md](operations/TOOLING_SETUP.md) |
| Install platform capabilities | [platform-engineering/PLATFORM_INSTALLATION.md](platform-engineering/PLATFORM_INSTALLATION.md) |
| Install Backstage integration | [integrations/BACKSTAGE_PLUGIN_GUIDE.md](integrations/BACKSTAGE_PLUGIN_GUIDE.md) |
| Use `koncept` commands | [developer/CLI_REFERENCE.md](developer/CLI_REFERENCE.md) |
| Understand the architecture | [platform-engineering/PROJECT_ARCHITECTURE.md](platform-engineering/PROJECT_ARCHITECTURE.md) |
| Add or modify framework templates | [platform-engineering/FRAMEWORK_EXTENSION_GUIDE.md](platform-engineering/FRAMEWORK_EXTENSION_GUIDE.md) |
| Run validation and acceptance tests | [testing/README.md](testing/README.md) |
| Operate governance checks | [operations/OPERATING_MODEL.md](operations/OPERATING_MODEL.md) |
| Review roadmap and strategy | [strategy/IDP_EVOLUTION_PLAN.md](strategy/IDP_EVOLUTION_PLAN.md) |

## Archive Policy

Active docs should explain current behavior. Dated implementation notes, completion reports, and superseded checklists belong in [archive/](archive/). When an archived document conflicts with an active guide, the active guide wins.

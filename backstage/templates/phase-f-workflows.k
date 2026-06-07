"""
Phase F: Backstage Self-Service Workflows

This module provides Backstage workflow templates that enable developers
to self-service:
1. Create new application (webapp)
2. Create new database (postgres/mongodb)
3. Create new environment (dev/staging/prod)
4. Promote stack to environment

Each workflow scaffolds the corresponding project structure and integrates
with the Go CLI (koncept).
"""

import catalog.components as backstage_components
import catalog.templates as backstage_templates

# --- Template 1: Create New Application ---

create_app_template = backstage_templates.Template {
    name = "create-app"
    title = "Create New Application"
    description = "Bootstrap a new web application with default configuration"
    owner = "platform-engineering"
    lifecycle = "production"

    parameters = [
        {
            title = "Project Name"
            description = "Name of the application (e.g., 'user-service')"
            ui.field = "ui:ObjectFieldTemplate"
            ui.options.rows = 3
        }
        {
            title = "Team"
            description = "Team that owns this application"
            enum = ["backend", "frontend", "data-eng", "platform"]
        }
        {
            title = "Runtime"
            description = "Programming language/runtime"
            enum = ["python", "go", "nodejs", "java", "rust"]
        }
        {
            title = "Port"
            description = "Application port (default: 8080)"
            type = "integer"
            default = 8080
        }
        {
            title = "Replicas"
            description = "Initial replica count"
            type = "integer"
            default = 1
            minimum = 1
            maximum = 10
        }
    ]

    steps = [
        {
            id = "create-structure"
            name = "Create project structure"
            action = "backstage:scaffolder:create-project"
            input = {
                url = "https://github.com/company/app-template"
                targetPath = "projects/${{ parameters.name }}"
                values = {
                    name = "${{ parameters.name }}"
                    team = "${{ parameters.team }}"
                    runtime = "${{ parameters.runtime }}"
                }
            }
        }
        {
            id = "initialize-stack"
            name = "Initialize KCL stack configuration"
            action = "idp:koncept:init-stack"
            input = {
                projectPath = "projects/${{ parameters.name }}"
                stackName = "${{ parameters.name }}"
                stackVersion = "0.0.1"
                components = [{
                    name = "${{ parameters.name }}"
                    type = "webapp"
                    port = "${{ parameters.port }}"
                    replicas = "${{ parameters.replicas }}"
                    runtime = "${{ parameters.runtime }}"
                }]
            }
        }
        {
            id = "render-stack"
            name = "Generate initial manifests"
            action = "idp:koncept:render"
            input = {
                projectPath = "projects/${{ parameters.name }}"
                outputFormat = "yaml"
                catalogPath = "projects/${{ parameters.name }}/pre_releases/dev"
            }
        }
        {
            id = "register-component"
            name = "Register application in catalog"
            action = "backstage:catalog:create"
            input = {
                name = "${{ parameters.name }}"
                apiVersion = "backstage.io/v1alpha1"
                kind = "Component"
                spec = {
                    type = "service"
                    owner = "${{ parameters.team }}"
                    lifecycle = "production"
                    system = "idp-concept"
                }
                relationsData = []
            }
        }
        {
            id = "push-repo"
            name = "Push to Git repository"
            action = "publish:github"
            input = {
                allowedHosts = ["github.com"]
                description = "New application: ${{ parameters.name }}"
                repoUrl = "github.com?owner=company&repo=${{ parameters.name }}&visibility=private"
            }
        }
    ]

    output = {
        repositoryUrl = "${{ steps['push-repo'].output.repositoryUrl }}"
        remoteUrl = "${{ steps['push-repo'].output.remoteUrl }}"
        componentRef = "component:default/${{ parameters.name }}"
    }
}

# --- Template 2: Create New Database ---

create_database_template = backstage_templates.Template {
    name = "create-database"
    title = "Create New Database"
    description = "Provision a new managed database (PostgreSQL, MongoDB)"
    owner = "platform-engineering"
    lifecycle = "production"

    parameters = [
        {
            title = "Database Name"
            description = "Name of the database service"
        }
        {
            title = "Database Type"
            description = "Database engine to provision"
            enum = ["postgresql", "mongodb", "redis", "mysql"]
        }
        {
            title = "Environment"
            description = "Target environment for the database"
            enum = ["dev", "staging", "production"]
        }
        {
            title = "Storage Size"
            description = "Storage allocation (e.g., '10Gi', '50Gi', '100Gi')"
            default = "10Gi"
        }
        {
            title = "Backup Enabled"
            description = "Enable automated backups"
            type = "boolean"
            default = True
        }
        {
            title = "High Availability"
            description = "Enable replication for high availability"
            type = "boolean"
            default = False
        }
    ]

    steps = [
        {
            id = "create-manifest"
            name = "Create database manifest"
            action = "idp:koncept:create-module"
            input = {
                moduleType = "accessory"
                moduleKind = "${{ parameters.databaseType }}"
                outputPath = "manifests/databases/${{ parameters.databaseName }}_module_def.k"
                spec = {
                    name = "${{ parameters.databaseName }}"
                    storageSize = "${{ parameters.storageSize }}"
                    backupEnabled = "${{ parameters.backupEnabled }}"
                    highAvailability = "${{ parameters.highAvailability }}"
                }
            }
        }
        {
            id = "add-to-stack"
            name = "Add database to stack"
            action = "idp:koncept:add-to-stack"
            input = {
                stackPath = "stacks/${{ parameters.environment }}_stack.k"
                moduleRef = "manifests.databases.${{ parameters.databaseName }}_module_def"
                moduleName = "${{ parameters.databaseName }}"
            }
        }
        {
            id = "generate-manifests"
            name = "Generate Kubernetes manifests"
            action = "idp:koncept:render"
            input = {
                stackPath = "stacks/${{ parameters.environment }}_stack.k"
                outputFormat = "yaml"
            }
        }
        {
            id = "create-credentials"
            name = "Create database credentials secret"
            action = "kubernetes:create-secret"
            input = {
                secretName = "${{ parameters.databaseName }}-credentials"
                namespace = "default"
                type = "Opaque"
                data = {
                    "password" = "$(openssl rand -base64 32)"
                }
            }
        }
        {
            id = "document-connection"
            name = "Document connection details"
            action = "idp:documentation:create"
            input = {
                title = "Database: ${{ parameters.databaseName }}"
                path = "docs/databases/${{ parameters.databaseName }}.md"
                content = """
                # Database: ${{ parameters.databaseName }}

                **Type**: ${{ parameters.databaseType }}
                **Environment**: ${{ parameters.environment }}
                **Storage**: ${{ parameters.storageSize }}
                **HA**: ${{ parameters.highAvailability }}

                ## Connection Details

                Connection credentials stored in: `${{ parameters.databaseName }}-credentials` secret

                ### Environment Variables
                - `DB_HOST`: ${{ parameters.databaseName }}.default.svc.cluster.local
                - `DB_USER`: From secret
                - `DB_PASSWORD`: From secret

                See E2_OPERATING_RUNBOOK.md for management procedures.
                """
            }
        }
    ]

    output = {
        modulePath = "manifests/databases/${{ parameters.databaseName }}_module_def.k"
        credsSecret = "${{ parameters.databaseName }}-credentials"
        documentationUrl = "docs/databases/${{ parameters.databaseName }}.md"
    }
}

# --- Template 3: Create New Environment ---

create_environment_template = backstage_templates.Template {
    name = "create-environment"
    title = "Create New Environment"
    description = "Bootstrap a new deployment environment (dev/staging/prod)"
    owner = "platform-engineering"
    lifecycle = "production"

    parameters = [
        {
            title = "Environment Name"
            description = "Name of the environment (e.g., 'staging-v2')"
        }
        {
            title = "Environment Tier"
            description = "Environment classification"
            enum = ["dev", "staging", "production"]
        }
        {
            title = "Cluster"
            description = "Target Kubernetes cluster"
            enum = ["kind-local", "staging-cluster", "prod-us-east", "prod-eu-west"]
        }
        {
            title = "Footprint"
            description = "Infrastructure sizing profile"
            enum = ["local", "development", "staging", "production"]
        }
        {
            title = "Enable Monitoring"
            description = "Deploy observability stack"
            type = "boolean"
            default = True
        }
        {
            title = "Enable Ingress"
            description = "Setup ingress controller"
            type = "boolean"
            default = True
        }
    ]

    steps = [
        {
            id = "create-site-config"
            name = "Create site configuration"
            action = "idp:koncept:create-site"
            input = {
                siteName = "${{ parameters.environmentName }}"
                siteTier = "${{ parameters.environmentTier }}"
                footprint = "${{ parameters.footprint }}"
                cluster = "${{ parameters.cluster }}"
                outputPath = "sites/${{ parameters.environmentName }}/"
            }
        }
        {
            id = "configure-namespace"
            name = "Configure namespaces"
            action = "idp:koncept:configure-namespaces"
            input = {
                sitePath = "sites/${{ parameters.environmentName }}/"
                namespaces = ["default", "monitoring", "istio-system"]
            }
        }
        {
            id = "setup-monitoring"
            name = "Setup monitoring stack"
            condition = "${{ parameters.enableMonitoring }}"
            action = "idp:koncept:add-observability"
            input = {
                sitePath = "sites/${{ parameters.environmentName }}/"
                components = ["prometheus", "grafana", "alertmanager"]
            }
        }
        {
            id = "setup-ingress"
            name = "Setup ingress controller"
            condition = "${{ parameters.enableIngress }}"
            action = "idp:koncept:add-ingress"
            input = {
                sitePath = "sites/${{ parameters.environmentName }}/"
                controller = "nginx"
            }
        }
        {
            id = "generate-site-manifests"
            name = "Generate environment manifests"
            action = "idp:koncept:render"
            input = {
                sitePath = "sites/${{ parameters.environmentName }}/"
                outputFormat = "yaml"
            }
        }
        {
            id = "create-argocd-app"
            name = "Create ArgoCD Application"
            action = "argocd:application:create"
            input = {
                name = "${{ parameters.environmentName }}"
                repoUrl = "https://github.com/company/platform-config"
                path = "sites/${{ parameters.environmentName }}"
                cluster = "${{ parameters.cluster }}"
                namespace = "argocd"
            }
        }
    ]

    output = {
        environmentPath = "sites/${{ parameters.environmentName }}/"
        argocdApp = "${{ parameters.environmentName }}"
        clusterUrl = "${{ steps['create-argocd-app'].output.clusterUrl }}"
    }
}

# --- Template 4: Promote Stack to Environment ---

promote_stack_template = backstage_templates.Template {
    name = "promote-stack"
    title = "Promote Stack to Environment"
    description = "Promote an application stack from one environment to another"
    owner = "platform-engineering"
    lifecycle = "production"

    parameters = [
        {
            title = "Application"
            description = "Application to promote"
            # Could be dynamic from catalog
        }
        {
            title = "Source Environment"
            description = "Current environment"
            enum = ["dev", "staging", "production"]
        }
        {
            title = "Target Environment"
            description = "Destination environment"
            enum = ["dev", "staging", "production"]
        }
        {
            title = "Version"
            description = "Application version to promote (or 'latest')"
            default = "latest"
        }
        {
            title = "Change Log"
            description = "What is changing in this promotion?"
            ui.field = "ui:textarea"
        }
        {
            title = "Requires Approval"
            description = "Require manual approval before deploying"
            type = "boolean"
            default = True
        }
    ]

    steps = [
        {
            id = "fetch-stack"
            name = "Fetch stack configuration"
            action = "idp:koncept:fetch-stack"
            input = {
                application = "${{ parameters.application }}"
                environment = "${{ parameters.sourceEnvironment }}"
                version = "${{ parameters.version }}"
            }
        }
        {
            id = "validate-promotion"
            name = "Validate promotion path"
            action = "idp:koncept:validate-promotion"
            input = {
                sourceEnv = "${{ parameters.sourceEnvironment }}"
                targetEnv = "${{ parameters.targetEnvironment }}"
                application = "${{ parameters.application }}"
            }
        }
        {
            id = "render-target"
            name = "Render stack for target environment"
            action = "idp:koncept:render-for-env"
            input = {
                stackPath = "${{ steps['fetch-stack'].output.stackPath }}"
                targetEnvironment = "${{ parameters.targetEnvironment }}"
            }
        }
        {
            id = "create-pr"
            name = "Create promotion pull request"
            action = "publish:github:pull-request"
            input = {
                title = "Promote ${{ parameters.application }} to ${{ parameters.targetEnvironment }}"
                description = """
## Promotion Details

**Application**: ${{ parameters.application }}
**From**: ${{ parameters.sourceEnvironment }}
**To**: ${{ parameters.targetEnvironment }}
**Version**: ${{ parameters.version }}

## Changes

${{ parameters.changeLog }}

## Validation

- Stack rendered for ${{ parameters.targetEnvironment }} environment
- All dependencies verified
- Ready for review and deployment
"""
                targetBranch = "main"
                repoUrl = "github.com?owner=company&repo=platform-config"
                requiresApproval = "${{ parameters.requiresApproval }}"
            }
        }
        {
            id = "notify-team"
            name = "Notify team of promotion"
            action = "idp:notification:send"
            input = {
                channel = "slack"
                message = """
🚀 Stack Promotion Ready

**App**: ${{ parameters.application }}
**Promotion**: ${{ parameters.sourceEnvironment }} → ${{ parameters.targetEnvironment }}
**Version**: ${{ parameters.version }}

PR: ${{ steps['create-pr'].output.prUrl }}
"""
            }
        }
    ]

    output = {
        pullRequestUrl = "${{ steps['create-pr'].output.prUrl }}"
        promotionStatus = "pending-review"
    }
}

# --- Backstage Actions (Custom Integration) ---

backstage_actions = {
    # E2 Workflow Actions
    "idp:koncept:init-stack" = {
        description = "Initialize a KCL stack scaffold for a project"
        id = "koncept-init-stack"
        schema = {
            input = {
                projectPath: string
                stackName: string
                stackVersion: string
                components: [{
                    name: string
                    type: string
                    port: integer
                }]
            }
        }
    }

    "idp:koncept:render" = {
        description = "Render KCL stack to output format (yaml/helm/crossplane)"
        id = "koncept-render"
        schema = {
            input = {
                projectPath: string
                outputFormat: string
                catalogPath: string
            }
        }
    }

    "idp:koncept:create-module" = {
        description = "Generate a new module definition (component/accessory)"
        id = "koncept-create-module"
    }

    "idp:koncept:add-to-stack" = {
        description = "Add a module to a stack definition"
        id = "koncept-add-to-stack"
    }

    "idp:koncept:create-site" = {
        description = "Create a new site (environment) configuration"
        id = "koncept-create-site"
    }

    "idp:koncept:fetch-stack" = {
        description = "Fetch stack configuration from Git"
        id = "koncept-fetch-stack"
    }

    "idp:koncept:validate-promotion" = {
        description = "Validate that a stack can be promoted"
        id = "koncept-validate-promotion"
    }

    "idp:koncept:render-for-env" = {
        description = "Render stack targeting specific environment"
        id = "koncept-render-for-env"
    }
}

# --- Summary ---

{
    templates = [
        create_app_template
        create_database_template
        create_environment_template
        promote_stack_template
    ]
    customActions = backstage_actions
    integrations = {
        konceptCLI = "cmd/koncept"
        kubernetesProvider = "crossplane-provider-kubernetes"
        gitHubActions = ".github/workflows"
        argoCD = "argocd"
    }
}


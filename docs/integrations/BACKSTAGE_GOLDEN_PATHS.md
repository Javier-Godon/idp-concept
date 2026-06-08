# Backstage Golden Paths — Self-Service Platform Workflows

> Blueprints for Backstage scaffolder templates that integrate with the `koncept` CLI to enable self-service workflows without exposing KCL internals. Each template generates validated configs and optionally auto-applies via CI/CD.

---

## Overview

Backstage should be the **primary interface** for platform users who are not KCL experts. Behind the scenes, Backstage scaffolder templates invoke the same `koncept` CLI commands that local developers use, ensuring consistency and testability.

---

## Architecture: Template → CLI → Render

```
User in Backstage
  ↓
  Template form (project name, service type, environment)
  ↓
  Custom action: invoke `koncept init project` + `koncept init module` + `koncept init env`
  ↓
  Generated scaffolding with markers (`# koncept:imports:end`, etc.)
  ↓
  Auto-wire: `koncept init module --wire` populates stack
  ↓
  Validate: `koncept policy check` + `koncept validate`
  ↓
  Commit PR with generated code
  ↓
  Review in GitHub + merge
  ↓ (optional)
  Auto-render + deploy via `koncept render` in CI/CD
```

---

## Template 1: New Web Application

**Goal**: Developer creates a new web service in < 5 minutes.

**File**: `backstage/templates/new-webapp.yaml`

```yaml
apiVersion: backstage.io/v1beta2
kind: Template
metadata:
  name: new-webapp
  title: "New Web Application"
  description: "Create a new web service (Node.js, Python, Go, Java)"
  tags:
    - webapp
    - recommended
spec:
  owner: platform-team
  type: service
  parameters:
    - title: Service Details
      required:
        - serviceName
        - serviceLang
        - servicePort
      properties:
        serviceName:
          title: Service Name
          type: string
          pattern: "^[a-z][a-z0-9-]*$"
          description: "e.g., api-gateway, user-service"
          examples:
            - "api-gateway"
            - "user-service"
            - "payment-processor"
        serviceLang:
          title: Language
          type: string
          enum:
            - nodejs
            - python
            - go
            - java
        servicePort:
          title: Container Port
          type: number
          default: 3000
          minimum: 1024
          maximum: 65535
        replicas:
          title: Initial Replicas
          type: number
          default: 2
          minimum: 1
          maximum: 10
        cpuRequest:
          title: CPU Request
          type: string
          default: "250m"
          description: "e.g., 100m, 500m, 1"
        memRequest:
          title: Memory Request
          type: string
          default: "512Mi"
    - title: Deployment Environment
      required:
        - environment
      properties:
        environment:
          title: Initial Environment
          type: string
          enum:
            - dev
            - staging
            - production
          default: dev
        tenant:
          title: Tenant/Customer (optional)
          type: string
          description: "Leave blank if multi-tenant not needed"

  steps:
    - id: fetch-base
      name: Fetch Base
      action: fetch:template
      input:
        url: https://github.com/Javier-Godon/idp-concept/tree/main/backstage/templates/webapp-scaffold
        values:
          serviceName: ${{ parameters.serviceName }}
          serviceLang: ${{ parameters.serviceLang }}

    - id: publish-to-github
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts:
          - github.com
        description: "Auto-generated web service for ${{ parameters.serviceName }}"
        repoUrl: "github.com?owner=Javier-Godon&repo=idp-projects"
        defaultBranch: main
        protectBranchDefault: false

    - id: koncept-init-project
      name: Initialize Koncept Project
      action: koncept:init:project
      input:
        projectName: ${{ parameters.serviceName }}
        projectPath: ${{ steps['publish-to-github'].output.repositoryUrl }}/projects/${{ parameters.serviceName }}
        framework: "../../framework"  # local path or GHCR reference when available

    - id: koncept-init-module
      name: Create Web Application Module
      action: koncept:init:module
      input:
        projectPath: ${{ steps['publish-to-github'].output.repositoryUrl }}/projects/${{ parameters.serviceName }}
        moduleType: webapp
        moduleName: ${{ parameters.serviceName }}
        port: ${{ parameters.servicePort }}
        replicas: ${{ parameters.replicas }}
        cpuRequest: ${{ parameters.cpuRequest }}
        memoryRequest: ${{ parameters.memRequest }}
        wire: true  # auto-wire into stack

    - id: koncept-init-env
      name: Create Environment
      action: koncept:init:env
      input:
        projectPath: ${{ steps['publish-to-github'].output.repositoryUrl }}/projects/${{ parameters.serviceName }}
        envName: ${{ parameters.environment }}
        serviceType: ClusterIP

    - id: koncept-validate
      name: Validate Configuration
      action: koncept:validate
      input:
        projectPath: ${{ steps['publish-to-github'].output.repositoryUrl }}/projects/${{ parameters.serviceName }}
        factory: "pre_releases/manifests/${{ parameters.environment }}/factory"

    - id: create-pr
      name: Create Pull Request
      action: github:createPullRequest
      input:
        repoUrl: ${{ steps['publish-to-github'].output.repositoryUrl }}
        title: "feat: scaffolded web app ${{ parameters.serviceName }}"
        description: |
          Auto-generated web application scaffold.
          
          **Service**: ${{ parameters.serviceName }}
          **Language**: ${{ parameters.serviceLang }}
          **Port**: ${{ parameters.servicePort }}
          **Environment**: ${{ parameters.environment }}
          
          Review the generated policy errors and address any before merge.
        targetBranchName: main
        draft: false

  output:
    links:
      - title: Pull Request
        url: ${{ steps['create-pr'].output.pullRequestUrl }}
      - title: Project Directory
        url: ${{ steps['publish-to-github'].output.repositoryUrl }}/tree/main/projects/${{ parameters.serviceName }}
```

---

## Template 2: Add Database/Cache/Queue to Existing Project

**Goal**: Quickly add infrastructure to an app.

**File**: `backstage/templates/add-infrastructure.yaml`

```yaml
apiVersion: backstage.io/v1beta2
kind: Template
metadata:
  name: add-infrastructure
  title: "Add Infrastructure (DB / Cache / Queue)"
  description: "Add PostgreSQL, Redis, RabbitMQ, Kafka to an existing project"
  tags:
    - infrastructure
    - postgres
    - redis
    - rabbitmq
    - kafka
spec:
  owner: platform-team
  type: resource
  parameters:
    - title: Target Project
      required:
        - projectPath
      properties:
        projectPath:
          title: Project Path
          type: string
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: Component
              type: service
    - title: Infrastructure Service
      required:
        - infraType
      properties:
        infraType:
          title: Service Type
          type: string
          enum:
            - postgres
            - redis
            - rabbitmq
            - kafka
            - mongodb
        infraName:
          title: Service Name
          type: string
          pattern: "^[a-z][a-z0-9-]*$"
          description: "e.g., user-db, cache-layer, event-queue"
        storageSize:
          title: Storage Size
          type: string
          default: "20Gi"
          enum:
            - "10Gi"
            - "20Gi"
            - "50Gi"
            - "100Gi"
            - "500Gi"
        replicas:
          title: Replicas (HA)
          type: number
          default: 3
          enum:
            - 1
            - 3
            - 5

  steps:
    - id: koncept-init-module
      name: Create Infrastructure Module
      action: koncept:init:module
      input:
        projectPath: ${{ parameters.projectPath }}
        moduleType: ${{ parameters.infraType }}
        moduleName: ${{ parameters.infraName }}
        storageSize: ${{ parameters.storageSize }}
        replicas: ${{ parameters.replicas }}
        wire: true

    - id: koncept-validate
      name: Validate Configuration
      action: koncept:validate
      input:
        projectPath: ${{ parameters.projectPath }}

    - id: create-pr
      name: Create Pull Request
      action: github:createPullRequest
      input:
        repoUrl: ${{ parameters.projectPath }}
        title: "feat: add ${{ parameters.infraType }} '${{ parameters.infraName }}' to ${{ parameters.projectPath }}"
        description: |
          Auto-generated infrastructure module.
          
          **Service**: ${{ parameters.infraType }}
          **Name**: ${{ parameters.infraName }}
          **Storage**: ${{ parameters.storageSize }}
          **Replicas**: ${{ parameters.replicas }}
        draft: false

  output:
    links:
      - title: Pull Request
        url: ${{ steps['create-pr'].output.pullRequestUrl }}
```

---

## Template 3: Promote Release to Environment

**Goal**: Move a release from staging → production with approvals.

**File**: `backstage/templates/promote-release.yaml`

```yaml
apiVersion: backstage.io/v1beta2
kind: Template
metadata:
  name: promote-release
  title: "Promote Release to Environment"
  description: "Render and deploy a specific version to staging or production"
  tags:
    - deployment
    - release
    - production
spec:
  owner: platform-team
  type: deployment
  parameters:
    - title: Release Details
      required:
        - projectName
        - version
        - targetEnv
      properties:
        projectName:
          title: Project
          type: string
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: Component
              type: service
        version:
          title: Release Version
          type: string
          pattern: "^v?[0-9]+\\.[0-9]+\\.[0-9]+.*$"
          description: "e.g., v1.0.0, v2.1.0-rc1"
          examples:
            - "v1.0.0"
            - "v1.1.0"
            - "v2.0.0-beta.1"
        targetEnv:
          title: Target Environment
          type: string
          enum:
            - staging
            - production
          default: staging
        renderFormat:
          title: Render Format
          type: string
          enum:
            - yaml
            - argocd
            - helmfile
          default: argocd
        approverEmail:
          title: Approver Email (Production only)
          type: string
          description: "Required for production promotions"

  steps:
    - id: check-approval
      name: Check Approval
      action: koncept:approval:request
      if: ${{ parameters.targetEnv === 'production' }}
      input:
        approverEmail: ${{ parameters.approverEmail }}
        message: "Promote ${{ parameters.projectName }} version ${{ parameters.version }} to production"
        expiryMinutes: 1440  # 24 hours

    - id: koncept-render
      name: Render Manifests
      action: koncept:render
      input:
        projectPath: ${{ parameters.projectName }}
        factory: "releases/${{ parameters.version }}_${{ parameters.targetEnv }}/factory"
        format: ${{ parameters.renderFormat }}

    - id: create-pr
      name: Create Deployment PR
      action: github:createPullRequest
      input:
        title: "chore: promote ${{ parameters.projectName }} v${{ parameters.version }} → ${{ parameters.targetEnv }}"
        description: |
          Release promotion via Backstage.
          
          **Project**: ${{ parameters.projectName }}
          **Version**: ${{ parameters.version }}
          **Target**: ${{ parameters.targetEnv }}
          **Format**: ${{ parameters.renderFormat }}
          
          ✅ Policy checks passed
          ✅ Golden output verified
          
          [Approve and merge to deploy]
        draft: false

    - id: register-catalog
      name: Register in Catalog
      action: catalog:write
      input:
        entity: ${{ steps['create-pr'].output.entity }}

  output:
    links:
      - title: Deployment PR
        url: ${{ steps['create-pr'].output.pullRequestUrl }}
      - title: Rendered Manifests
        url: ${{ steps['koncept-render'].output.manifestsUrl }}
```

---

## Backstage Custom Action Integration

These templates require custom actions registered in `backstage/plugins/`:

### `koncept:init:project` Action
```typescript
export const konceptInitProject: createBackstageAction<{
  projectName: string;
  projectPath: string;
  framework?: string;
}> = createAction({
  id: 'koncept:init:project',
  description: 'Initialize a new Koncept project scaffold',
  async handler(input) {
    const { projectName, projectPath } = input;
    exec(`koncept init project "${projectName}" --dest "${projectPath}"`);
  },
});
```

### `koncept:validate` Action
```typescript
export const konceptValidate: createBackstageAction<{
  projectPath: string;
  factory?: string;
}> = createAction({
  id: 'koncept:validate',
  description: 'Validate Koncept configuration',
  async handler(input) {
    const { projectPath, factory } = input;
    const result = exec(`koncept validate --factory "${projectPath}/${factory || 'factory'}"`);
    if (result.exitCode !== 0) throw new Error(result.stderr);
  },
});
```

---

## Implementation Roadmap

### Phase 1: Foundation (Sprint 1)
- [ ] Create custom action framework in `backstage/actions/`
- [ ] Scaffold Template 1 (new-webapp)
- [ ] Test locally with Backstage dev server

### Phase 2: Expansion (Sprint 2)
- [ ] Add Templates 2 & 3
- [ ] Integrate CI/CD approval workflow
- [ ] Document for end-users

### Phase 3: Production (Sprint 3)
- [ ] Deploy Backstage instance
- [ ] Train platform team
- [ ] Gather user feedback
- [ ] Iterate on workflow

---

## Success Metrics

- ✅ Developer can create project in < 5 minutes (vs. 30 min manual setup)
- ✅ No direct KCL editing required
- ✅ `koncept policy check` enforced in Backstage workflow
- ✅ PR created automatically with rendered diffs
- ✅ Team adopts Backstage as primary interface (NPS ≥ +50)

---

## References

- **Backstage docs**: https://backstage.io/docs/
- **Custom actions**: `backstage/plugins/actions/`
- **CLI commands**: `koncept --help`
- **Templates**: `framework/templates/`


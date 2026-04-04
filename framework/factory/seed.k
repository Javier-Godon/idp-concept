"""
Factory Seed — standard factory setup that merges 4 configuration layers,
creates a Release, and produces the render contract variables.

Eliminates the repetitive factory_seed.k pattern in every pre_release/release.
Each factory_seed.k becomes a thin wrapper that only provides environment-specific inputs.

Usage:
    import framework.factory.seed as seed

    _factory = seed.FactorySeed {
        releaseName = "pre_release_dev"
        version = "1.0.0"
        project = my_project
        profile = my_profile
        tenant = my_tenant
        site = my_site
        mergeFunc = merge.merge_configurations
        stackSchema = MyStack
        gitRepoUrl = "https://github.com/org/repo"
        manifestPath = "projects/my_project/pre_releases/manifests/dev/output"
    }

    # Render contract variables (used by render.k):
    _stack = _factory.renderStack
    _project_name = _factory.projectName
    _git_repo_url = _factory.gitRepoUrl
    _manifest_path = _factory.manifestPath
"""
import models.release as release_model
import models.profile as profile_model
import models.project as project_model
import models.tenant as tenant_model
import models.site as site_model
import models.manifests.renderstack as rs

schema FactorySeed:
    """Factory seed that merges configs, builds stack, and exports render contract."""
    releaseName: str
    version: str
    project: project_model.Project
    profile: profile_model.Profile
    tenant: tenant_model.Tenant
    site: site_model.Site
    # framework-generic: higher-order function — merge lambda varies per project
    mergeFunc: any
    # framework-generic: stack schema type varies per project
    stackSchema: any
    # Render contract inputs
    gitRepoUrl: str
    manifestPath: str

    # Auto-computed: merge all 4 layers
    mergedConfigurations: any = mergeFunc(
        project.configurations,
        profile.configurations,
        tenant.configurations,
        site.configurations
    )

    # Auto-computed: instantiate the stack with merged config
    stack = stackSchema {
        instanceConfigurations = mergedConfigurations
    }

    # Auto-computed: create the release
    release = release_model.Release {
        name = releaseName
        version = version
        project = project.instance
        tenant = tenant.instance
        site = site.instance
        profile = profile.instance
        stack = stack
    }

    # === Render contract outputs (used by render.k) ===
    renderStack: rs.RenderStack = rs.RenderStack {
        instanceConfigurations = stack.instanceConfigurations
        k8snamespaces = stack.k8snamespaces
        components = stack.components
        accessories = stack.accessories
    }
    projectName: str = project.instance.name

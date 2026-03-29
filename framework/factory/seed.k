"""
Factory Seed — standard factory setup that merges 4 configuration layers and creates a Release.
Replaces the repetitive factory_seed.k pattern in every pre_release/release.

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
    }
    # Access: _factory.stack, _factory.release, _factory.mergedConfigurations
"""
import models.release as release_model
import models.profile as profile_model
import models.project as project_model
import models.tenant as tenant_model
import models.site as site_model

schema FactorySeed:
    releaseName: str
    version: str
    project: project_model.Project
    profile: profile_model.Profile
    tenant: tenant_model.Tenant
    site: site_model.Site
    mergeFunc: any
    stackSchema: any

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

import factory.conventions

_release_factory_path = "/repo/projects/erp_back/releases/v1_0_0_production/factory/factory_seed.k"
_pre_release_factory_path = "/repo/projects/erp_back/pre_releases/manifests/dev/factory/factory_seed.k"
_versioned_profile_path = "/repo/projects/erp_back/stacks/versioned/v1_0_0/profile_def.k"
_development_profile_path = "/repo/projects/erp_back/stacks/development/profile_def.k"
_tenant_path = "/repo/projects/erp_back/tenants/acme_corp/tenant_def.k"
_default_site_path = "/repo/projects/erp_back/sites/production/default/site_def.k"
_cluster_site_path = "/repo/projects/erp_back/sites/development/dev_cluster/site_def.k"

test_context_from_release_path = lambda {
    _ctx = conventions.context_from_path(_release_factory_path)

    assert _ctx.projectSlug == "erp_back"
    assert _ctx.releaseKind == "release"
    assert _ctx.releaseID == "v1_0_0_production"
    assert _ctx.environment == "production"
    assert _ctx.version == "1.0.0"
    assert _ctx.releaseName == "release_v1_0_0_production"
    assert _ctx.manifestPath == "projects/erp_back/releases/v1_0_0_production/output"
}

test_context_from_pre_release_path = lambda {
    _ctx = conventions.context_from_path(_pre_release_factory_path)

    assert _ctx.projectSlug == "erp_back"
    assert _ctx.releaseKind == "pre_release"
    assert _ctx.releaseID == "dev"
    assert _ctx.environment == "dev"
    assert _ctx.version == "0.0.0-dev"
    assert _ctx.releaseName == "pre_release_dev"
    assert _ctx.manifestPath == "projects/erp_back/pre_releases/manifests/dev/output"
}

test_profile_names_from_stack_paths = lambda {
    assert conventions.profile_name_from_path(_versioned_profile_path) == "v1_0_0"
    assert conventions.profile_name_from_path(_development_profile_path) == "development"
}

test_tenant_and_site_names_from_paths = lambda {
    assert conventions.tenant_id_from_path(_tenant_path) == "acme_corp"
    assert conventions.slug_to_display_name("acme_corp") == "Acme Corp"
    assert conventions.site_name_from_path(_default_site_path) == "production"
    assert conventions.site_name_from_path(_cluster_site_path) == "dev_cluster"
}

test_build_profile_tenant_site = lambda {
    _profile = conventions.build_profile(conventions.ProfileSpec {
        currentFile = _versioned_profile_path
        configurations = { appsNamespace = "erp-apps" }
    })
    _tenant = conventions.build_tenant(conventions.TenantSpec {
        currentFile = _tenant_path
        configurations = { brandIcon = "acme-logo" }
    })
    _site = conventions.build_site(conventions.SiteSpec {
        currentFile = _default_site_path
        tenant = _tenant
        configurations = { siteName = "production" }
    })

    assert _profile.name == "v1_0_0"
    assert _profile.configurations.appsNamespace == "erp-apps"
    assert _tenant.name == "Acme Corp"
    assert _tenant.configurations.brandIcon == "acme-logo"
    assert _site.name == "production"
    assert _site.tenant.name == "Acme Corp"
}

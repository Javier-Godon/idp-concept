"""
Factory seed for erp_back v1.0.0 production release.
Uses the framework FactorySeed to eliminate boilerplate.

Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""
import framework.factory.seed as seed
import erp_back.stacks.versioned.v1_0_0.stack_def as stack
import erp_back.stacks.versioned.v1_0_0.profile_def
import erp_back.tenants.acme_corp.tenant_def
import erp_back.sites.production.default.site_def
import erp_back.kernel.project_def
import erp_back.core_sources.merge_configurations as merge

_factory = seed.FactorySeed {
    releaseName = "release_v1_0_0_production"
    version = "1.0.0"
    project = project_def.erp_back_project
    profile = profile_def.erp_back_v1_0_0_profile
    tenant = tenant_def.tenant_acme
    site = site_def.production_site
    mergeFunc = merge.merge_configurations
    stackSchema = stack.ErpBackV1_0_0Stack
    gitRepoUrl = "https://github.com/Javier-Godon/idp-concept"
    manifestPath = "projects/erp_back/releases/v1_0_0_production/output"
}

# Render contract variables for render.k
_stack = _factory.renderStack
_project_name = _factory.projectName
_git_repo_url = _factory.gitRepoUrl
_manifest_path = _factory.manifestPath

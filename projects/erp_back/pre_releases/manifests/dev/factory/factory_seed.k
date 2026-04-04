"""
Factory seed for erp_back dev pre-release.
Uses the framework FactorySeed to eliminate boilerplate.

Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""
import framework.factory.seed as seed
import erp_back.stacks.development.stack_def
import erp_back.stacks.development.profile_def
import erp_back.tenants.vendor
import erp_back.sites.development.dev_cluster.site_def
import erp_back.kernel.project_def
import erp_back.core_sources.merge_configurations as merge

_factory = seed.FactorySeed {
    releaseName = "pre_release_dev"
    version = "0.0.1-dev"
    project = project_def.erp_back_project
    profile = profile_def.erp_back_development_profile
    tenant = vendor.tenant_vendor
    site = site_def.dev_cluster_site
    mergeFunc = merge.merge_configurations
    stackSchema = stack_def.ErpBackDevelopmentStack
    gitRepoUrl = "https://github.com/Javier-Godon/idp-concept"
    manifestPath = "projects/erp_back/pre_releases/manifests/dev/output"
}

# Render contract variables for render.k
_stack = _factory.renderStack
_project_name = _factory.projectName
_git_repo_url = _factory.gitRepoUrl
_manifest_path = _factory.manifestPath

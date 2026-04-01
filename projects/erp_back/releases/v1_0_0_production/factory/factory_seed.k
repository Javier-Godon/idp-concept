"""
Factory seed for erp_back v1.0.0 production release.
Follows the standardized factory_seed contract for render.k.

Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""
import framework.models.manifests.renderstack
import erp_back.stacks.versioned.v1_0_0.stack_def as stack
import erp_back.stacks.versioned.v1_0_0.profile_def
import erp_back.tenants.acme_corp.tenant_def
import erp_back.sites.production.default.site_def
import erp_back.kernel.project_def
import erp_back.core_sources.merge_configurations as merge

_tenant = tenant_def.tenant_acme
_project = project_def.erp_back_project
_site = site_def.production_site
_profile = profile_def.erp_back_v1_0_0_profile

_release_configurations = merge.merge_configurations(
    _project.configurations
    _profile.configurations
    _tenant.configurations
    _site.configurations
)

_base_stack = stack.ErpBackV1_0_0Stack {
    instanceConfigurations = _release_configurations
}

# Full stack for rendering (standardized contract variable)
_stack = renderstack.RenderStack {
    instanceConfigurations = _base_stack.instanceConfigurations
    k8snamespaces = _base_stack.k8snamespaces
    components = _base_stack.components
    accessories = _base_stack.accessories
}

# Standardized contract variables for render.k
_project_name = _project.instance.name
_git_repo_url = _release_configurations.gitRepoUrl
_manifest_path = "projects/erp_back/releases/v1_0_0_production/output"

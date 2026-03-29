"""
Pre-release configurations for dev cluster — merges all 4 configuration layers.
"""
import erp_back.stacks.development.stack_def
import erp_back.stacks.development.profile_def
import erp_back.tenants.vendor
import erp_back.sites.development.dev_cluster.site_def
import erp_back.kernel.project_def
import erp_back.core_sources.merge_configurations as merge

_tenant = vendor.tenant_vendor
_project = project_def.erp_back_project
_site = site_def.dev_cluster_site
_profile = profile_def.erp_back_development_profile

_pre_release_configurations_dev_cluster = merge.merge_configurations(
    _project.configurations
    _profile.configurations
    _tenant.configurations
    _site.configurations
)

_stack = stack_def.ErpBackDevelopmentStack {
    instanceConfigurations = _pre_release_configurations_dev_cluster
}

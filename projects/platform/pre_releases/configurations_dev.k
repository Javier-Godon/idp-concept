"""
Pre-release configurations for dev cluster — merges all 4 configuration layers.
"""

import platform.stacks.development.stack_def
import platform.stacks.development.profile_def
import platform.tenants.vendor
import platform.sites.development.dev_cluster.site_def
import platform.kernel.project_def
import framework.models.configurations as base

_tenant = vendor.tenant_vendor
_project = project_def.platform_project
_site = site_def.dev_cluster_site
_profile = profile_def.platform_development_profile

_pre_release_configurations_dev_cluster = base.merge_configurations(_project.configurations, _profile.configurations, _tenant.configurations, _site.configurations)

_stack = stack_def.PlatformDevelopmentStack {
    instanceConfigurations = _pre_release_configurations_dev_cluster
}

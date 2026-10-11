"""
Pre-release configurations for dev cluster — merges all 4 configuration layers.
"""

import nexus.stacks.development.stack_def
import nexus.stacks.development.profile_def
import nexus.tenants.vendor
import nexus.sites.development.dev_cluster.site_def
import nexus.kernel.project_def
import framework.models.configurations as base

_tenant = vendor.tenant_vendor
_project = project_def.nexus_project
_site = site_def.dev_cluster_site
_profile = profile_def.nexus_development_profile

_pre_release_configurations_dev_cluster = base.merge_configurations(_project.configurations, _profile.configurations, _tenant.configurations, _site.configurations)

_stack = stack_def.NexusDevelopmentStack {
    instanceConfigurations = _pre_release_configurations_dev_cluster
}

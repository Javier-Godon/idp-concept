import video_streaming.stacks.development.stack_def
import video_streaming.stacks.development.profile_def
import video_streaming.tenants.vendor
import video_streaming.sites.development.dev_cluster.site_def
import video_streaming.kernel.project_def
import video_streaming.core_sources.merge_configurations as merge

_tenant = vendor.tenant_vendor
_project = project_def.video_streaming_project
_site = site_def.dev_cluster_site
_profile = profile_def.video_streaming_development_profile

_pre_release_configurations_dev_cluster = merge.merge_configurations(_project.configurations, _profile.configurations, _tenant.configurations, _site.configurations)
_stack = stack_def.VideoStreamingDevelopmentStack {
    instanceConfigurations = _pre_release_configurations_dev_cluster
}

import stacks.versioned.v1_0_0.base.stack_def as stack
import stacks.versioned.v1_0_0.base.profile_def
import tenants.germany
import sites.tenants.production.berlin
import framework.models.release
import kernel.project_def
import core_sources.merge_configurations as merge

_tenant = germany.tenant_germany
_project = project_def.video_streaming_project
_site = berlin.berlin_stie
_profile = profile_def.video_streaming_v1_0_0_base_profile

_release_configurations = merge.merge_configurations(_project.configurations, _profile.configurations, _tenant.configurations, _site.configurations)
_stack = stack.VideoStreamingv1_0_0_BaseStack {
    instanceConfigurations = _release_configurations
}
_release_v1_0_0_berlin = release.Release {
    name = "release_v1_0_0_berlin"
    version = "1.0.0/berlin"
    project = _project.instance
    tenant = _tenant.instance
    site = _site.instance
    profile = _profile.instance
    stack = _stack
}
resources = _release_v1_0_0_berlin.kusionSpec



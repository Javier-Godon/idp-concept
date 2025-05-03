import stacks.versioned.v1_0_0.base.stack_def as stack
import tenants.germany
import sites.tenants.production.berlin
import kernel.configurations as kernel
import framework.models.release
import kernel.project_def

_release_v1_0_0_berlin = release.Release {
    name = "release_v1_0_0_berlin"
    version = "1.0.0/berlin"
    project = project_def.video_streaming_project.instance
    tenant = germany.tenant_germany.instance
    stack = stack.VideoStreamingv1_0_0_BaseStack {
        kernelConfigurations = kernel.video_streaming_kernel_configurations
        site = berlin.berlin_stie.instance
    }
    site = berlin.berlin_stie.instance
}

resources = _release_v1_0_0_berlin.kusionSpec

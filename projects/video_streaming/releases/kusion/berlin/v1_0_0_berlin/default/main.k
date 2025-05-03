import stacks.versioned.v1_0_0.base.stack_def as stack
import tenants.germany
import sites.tenants.production.berlin
import framework.models.release
import kernel.project_def

_release_v1_0_0_berlin = release.Release {
    name = "release_v1_0_0_berlin"
    version = "1.0.0/berlin"
    project = project_def.video_streaming_project.instance
    tenant = germany.tenant_germany.instance
    site = berlin.berlin_stie.instance
    stack = stack.VideoStreamingv1_0_0_BaseStack {
        project = project
        site = site
    }
}

resources = _release_v1_0_0_berlin.kusionSpec

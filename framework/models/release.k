"""
Combination of kernel, stack and site configurations that will generate a concrete version for a concrete tenant of an OCI artifact
"""
import procedures.kcl_to_kusion
import models.profile
import models.project
import models.tenant
import models.site
import models.stack
import models.metadata as meta
import models.release_notes as rn
import models.compatibility as compat

schema Release:
    name: str
    version: str
    metadata?: meta.Metadata
    compatibility?: compat.FrameworkCompatibility
    releaseNotes?: rn.ReleaseNotes
    project: project.ProjectInstance
    tenant: tenant.TenantInstance
    profile: profile.ProfileInstance
    site: site.SiteInstance
    stack: stack.Stack
    kusionSpec: [kcl_to_kusion.KusionResource] = kcl_to_kusion.kusion_spec_stream_stack(stack)

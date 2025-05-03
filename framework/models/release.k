"""
Combination of kernel, stack and site configurations that will generate a concrete version for a concrete tenant of an OCI artifact
"""
import procedures.kcl_to_kusion
import models.stack
import models.project
import models.tenant
import models.site

schema Release:
    name: str
    version: str
    project: project.ProjectInstance
    tenant: tenant.TenantInstance
    stack: stack.Stack
    site: site.SiteInstance
    kusionSpec: [kcl_to_kusion.KusionResource] = kcl_to_kusion.kusion_spec_stream_stack(stack)


"""
Concrete target workspace
"""
import models.tenant
import models.metadata as meta

schema SiteInstance:
    name: str
    tenant: tenant.Tenant
    metadata?: meta.Metadata
    # framework-generic: accepts any project config schema
    configurations: any

schema Site:
    instance: SiteInstance = SiteInstance {
        name = name
        tenant = tenant
        metadata = metadata
        configurations = configurations
    }
    name: str
    tenant: tenant.Tenant
    metadata?: meta.Metadata
    # framework-generic: accepts any project config schema
    configurations: any


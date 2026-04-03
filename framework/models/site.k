"""
Concrete target workspace
"""
import models.tenant

schema SiteInstance:
    name: str
    tenant: tenant.Tenant
    # framework-generic: accepts any project config schema
    configurations: any

schema Site:
    instance: SiteInstance = SiteInstance {
        name = name
        tenant = tenant
        configurations = configurations
    }
    name: str
    tenant: tenant.Tenant
    # framework-generic: accepts any project config schema
    configurations: any


"""
Concrete target workspace
"""
import models.tenant

schema SiteInstance:
    name: str
    tenant: tenant.Tenant
    configurations: any

schema Site:
    instance: SiteInstance = SiteInstance {
        name = name
        tenant = tenant
        configurations = configurations
    }
    name: str
    tenant: tenant.Tenant
    configurations: any


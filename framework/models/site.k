"""
Concrete target workspace
"""
import configs.models.site_config
import models.tenant

schema SiteInstance:
    name: str
    tenant: tenant.Tenant
    configurations: site_config.SiteConfig

schema Site:
    instance: SiteInstance = SiteInstance {
        name = name
        tenant = tenant
        configurations = configurations
    }
    name: str
    tenant: tenant.Tenant
    configurations: site_config.SiteConfig


import file
import framework.factory.conventions as conventions
import platform.tenants.vendor.tenant_def as tenant_def
import platform.core_sources.platform_configurations as cfg
import platform.sites.development.dev_cluster.configurations

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = cfg.PlatformConfigurations {
        **configurations._dev_cluster_site_configurations
    }
})

dev_cluster_site = site

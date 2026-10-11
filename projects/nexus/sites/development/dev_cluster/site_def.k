import file
import framework.factory.conventions as conventions
import nexus.tenants.vendor.tenant_def as tenant_def
import nexus.core_sources.nexus_configurations as cfg
import nexus.sites.development.dev_cluster.configurations

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = cfg.NexusConfigurations {
        **configurations._dev_cluster_site_configurations
    }
})

dev_cluster_site = site

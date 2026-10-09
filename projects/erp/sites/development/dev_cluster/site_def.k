import file
import framework.factory.conventions as conventions
import erp.tenants.vendor.tenant_def as tenant_def
import erp.core_sources.erp_configurations as cfg
import erp.sites.development.dev_cluster.configurations

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = cfg.ErpConfigurations {
        **configurations._dev_cluster_site_configurations
    }
})

dev_cluster_site = site

import file
import framework.factory.conventions as conventions
import erp_back.tenants.vendor.tenant_def as tenant_def
import erp_back.core_sources.erp_back_configurations
import erp_back.sites.development.dev_cluster.configurations

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = erp_back_configurations.ErpBackConfigurations {
        **configurations._dev_cluster_site_configurations
    }
})

dev_cluster_site = site


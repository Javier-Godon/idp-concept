import framework.models.site
import erp_back.tenants.vendor
import erp_back.core_sources.erp_back_configurations
import erp_back.sites.development.dev_cluster.configurations

dev_cluster_site = site.Site {
    name = "dev_cluster"
    tenant = vendor.tenant_vendor
    configurations = erp_back_configurations.ErpBackConfigurations {
        **configurations._dev_cluster_site_configurations
    }
}

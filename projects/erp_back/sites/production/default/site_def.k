import framework.models.site
import erp_back.tenants.acme_corp.tenant_def
import erp_back.core_sources.erp_back_configurations
import erp_back.sites.production.default.configurations

production_site = site.Site {
    name = "production"
    tenant = tenant_def.tenant_acme
    configurations = erp_back_configurations.ErpBackConfigurations {
        **configurations._production_site_configurations
    }
}

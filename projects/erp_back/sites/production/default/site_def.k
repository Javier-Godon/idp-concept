import file
import framework.factory.conventions as conventions
import erp_back.tenants.acme_corp.tenant_def
import erp_back.core_sources.erp_back_configurations
import erp_back.sites.production.default.configurations

site = conventions.build_site(conventions.SiteSpec {
    currentFile = file.current()
    tenant = tenant_def.tenant
    configurations = erp_back_configurations.ErpBackConfigurations {
        **configurations._production_site_configurations
    }
})

production_site = site


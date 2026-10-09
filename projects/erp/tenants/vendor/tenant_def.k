import file
import framework.factory.conventions as conventions
import erp.core_sources.erp_configurations as cfg

tenant = conventions.build_tenant(conventions.TenantSpec {
    currentFile = file.current()
    name = "Internal"
    description = "Internal vendor/development team"
    configurations = cfg.ErpConfigurations {
        brandIcon = "internal-logo"
    }
})

tenant_vendor = tenant

import file
import framework.factory.conventions as conventions
import erp_back.core_sources.erp_back_configurations

tenant = conventions.build_tenant(conventions.TenantSpec {
    currentFile = file.current()
    name = "Internal"
    description = "Internal vendor/development team"
    configurations = erp_back_configurations.ErpBackConfigurations {
        brandIcon = "internal-logo"
    }
})

tenant_vendor = tenant


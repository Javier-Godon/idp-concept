import file
import framework.factory.conventions as conventions
import erp_back.core_sources.erp_back_configurations

tenant = conventions.build_tenant(conventions.TenantSpec {
    currentFile = file.current()
    name = "ACME Corp"
    description = "ACME Corporation — enterprise customer"
    configurations = erp_back_configurations.ErpBackConfigurations {
        brandIcon = "acme-logo"
    }
})

tenant_acme = tenant


import framework.models.tenant
import erp_back.core_sources.erp_back_configurations

tenant_vendor = tenant.Tenant {
    name = "Internal"
    description = "Internal vendor/development team"
    configurations = erp_back_configurations.ErpBackConfigurations {
        brandIcon = "internal-logo"
    }
}

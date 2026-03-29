import framework.models.tenant
import erp_back.core_sources.erp_back_configurations

tenant_acme = tenant.Tenant {
    name = "ACME Corp"
    description = "ACME Corporation — enterprise customer"
    configurations = erp_back_configurations.ErpBackConfigurations {
        brandIcon = "acme-logo"
    }
}

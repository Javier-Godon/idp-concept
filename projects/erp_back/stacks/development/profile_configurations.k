import erp_back.core_sources.erp_back_configurations

_erp_back_profile_configurations = erp_back_configurations.ErpBackConfigurations {
    appsNamespace = "erp-apps"
    postgresNamespace = "erp-postgres"
    springProfile = "dev"
    postgresHost = "erp-postgres.erp-postgres.svc.cluster.local"
}

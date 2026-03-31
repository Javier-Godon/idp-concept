import erp_back.core_sources.erp_back_configurations

_erp_back_v1_0_0_profile_configurations = erp_back_configurations.ErpBackConfigurations {
    appsNamespace = "erp-apps"
    postgresNamespace = "erp-postgres"
    springProfile = "prod"
    postgresHost = "erp-postgres.erp-postgres.svc.cluster.local"
    javaOpts = "-Xmx2g -Xms1g"
}

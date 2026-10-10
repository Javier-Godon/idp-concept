import erp.core_sources.erp_configurations as cfg

_erp_profile_configurations = cfg.ErpConfigurations {
    cacheNamespace = "erp-data"
    postgresNamespace = "erp-postgres"
    postgresFootprint = "development"
    postgresDatabase = "blue_postgres"
    postgresSuperuserSecret = "erp-postgres-superuser"
    footprint = "development"
}

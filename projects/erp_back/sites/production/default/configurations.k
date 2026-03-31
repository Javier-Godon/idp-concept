import erp_back.core_sources.erp_back_configurations

_production_site_configurations = erp_back_configurations.ErpBackConfigurations {
    siteName = "production"
    rootPaths = {
        "postgres": "erp-postgres.erp-postgres.svc.cluster.local"
    }
}

import erp_back.core_sources.erp_back_configurations

_stg_cluster_site_configurations = erp_back_configurations.ErpBackConfigurations {
    siteName = "stg_cluster"
    rootPaths = {
        "postgres": "erp-postgres.erp-postgres.svc.cluster.local"
    }
}

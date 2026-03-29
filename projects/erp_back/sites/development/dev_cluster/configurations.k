import erp_back.core_sources.erp_back_configurations

_dev_cluster_site_configurations = erp_back_configurations.ErpBackConfigurations {
    siteName = "dev_cluster"
    rootPaths = {
        "postgres": "erp-postgres.erp-postgres.svc.cluster.local"
    }
}

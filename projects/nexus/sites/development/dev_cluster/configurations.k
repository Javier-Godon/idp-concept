import nexus.core_sources.nexus_configurations as cfg

_dev_cluster_site_configurations = cfg.NexusConfigurations {
    siteName = "dev_cluster"
    storageClassName = "local-path"
    useLocalPersistentVolumes = False
}

import erp.core_sources.erp_configurations as cfg

_dev_cluster_site_configurations = cfg.ErpConfigurations {
    siteName = "dev_cluster"
    storageClassName = "local-path"
    useLocalPersistentVolumes = True
    footprint = "local"
    postgresNodePort = 31543
    # Local clusters have no Ceph/Longhorn: etcd uses the local-path provisioner (production sets the Ceph block class).
    apisixEtcdStorageClass = "local-path"
}

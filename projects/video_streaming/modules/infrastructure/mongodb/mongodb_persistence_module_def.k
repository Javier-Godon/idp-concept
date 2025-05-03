import framework.models.modules.accessory as accessory

schema MongoDBPersistenceModule(accessory.Accessory):
    kind = "CRD"
    leaders = [
        accessory.AccessoryLeader {
            name = "${name}-pv"
            kind = "PersistentVolume"
            apiVersion = "v1"
            namespace = namespace
        }
        accessory.AccessoryLeader {
            name = "${name}-pvc"
            kind = "PersistentVolumeClaim"
            apiVersion = "v1"
            namespace = namespace
        }
    ]
    manifests = [
        {
            apiVersion = "v1"
            kind = "PersistentVolume"
            metadata = {
                name = "${name}-pv"
                labels = {
                    $type = "local"
                }
            namespace = namespace
            }
            spec = {
                storageClassName = "${name}-pv"
                accessModes = [
                    "ReadWriteOnce"
                ]
                capacity = {
                    storage = "20Gi"
                }
                persistentVolumeReclaimPolicy = "Retain"
                hostPath = {
                    path = "/mnt/data/mongodb-volume"
                }
            }
        }
        {
            apiVersion = "v1"
            kind = "PersistentVolumeClaim"
            metadata = {
                name = "${name}-pvc"
                namespace = namespace
            }
            spec = {
                storageClassName = "${name}-pv"
                accessModes = [
                    "ReadWriteOnce"
                ]
                resources = {
                    requests = {
                        storage = "20Gi"
                    }
                }
            }
        }
    ]


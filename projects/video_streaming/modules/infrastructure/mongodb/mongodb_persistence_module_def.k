import framework.models.modules.accessory as accessory
import framework.builders.storage as storage
import framework.builders.leader as leader

schema MongoDBPersistenceModule(accessory.Accessory):
    kind = "CRD"
    storageSize?: str = "20Gi"
    storageClassName?: str = "rook-ceph-block"
    useLocalPersistentVolume?: bool = False
    localHostPath?: str = "/mnt/data/mongodb-volume"

    leaders = [
        leader.build_accessory_leader("${name}-pvc", namespace, "PersistentVolumeClaim", "v1")
        if useLocalPersistentVolume:
            leader.build_accessory_leader("${name}-pv", namespace, "PersistentVolume", "v1")
    ]

    manifests = storage.build_pv_and_pvc(storage.PersistentVolumeSpec {
        name = name
        namespace = namespace
        size = storageSize
        storageClassName = storageClassName
        createPersistentVolume = useLocalPersistentVolume
        hostPath = localHostPath
    })


"""
Database Module Template — pre-built single-instance database pattern.
Generates: Deployment + Service + PV + PVC.

Usage:
    import framework.templates.database as database

    schema MyDB(database.SingleDatabaseModule):
        port = 27017
        dataPath = "/data/db"
        storageSize = "20Gi"
"""
import models.modules.accessory as accessory
import builders.deployment as deploy
import builders.service as svc
import builders.storage as storage
import builders.leader as leader

schema SingleDatabaseModule(accessory.Accessory):
    kind = "CRD"

    # User-configurable
    port: int
    dataPath?: str = "/data"
    storageSize?: str = "20Gi"
    storageHostPath?: str = "/mnt/data"
    serviceType?: str = "ClusterIP"
    nodePort?: int
    env?: [any]
    resources?: deploy.ResourceSpec
    imagePullPolicy?: str = "IfNotPresent"
    portName?: str

    # Auto-computed
    leaders = [leader.build_accessory_leader(name, namespace, "Deployment", "apps/v1")]

    _pv_pvc = storage.build_pv_and_pvc(storage.PersistentVolumeSpec {
        name = name
        namespace = namespace
        size = storageSize
        hostPath = "${storageHostPath}/${name}-volume"
    })

    _deployment = deploy.build_deployment(deploy.DeploymentSpec {
        name = name
        namespace = namespace
        image = asset.image
        version = asset.version
        port = port
        env = env
        resources = resources
        imagePullPolicy = imagePullPolicy
        volumeMounts = [{
            name = "${name}-pv"
            mountPath = dataPath
        }]
        volumes = [{
            name = "${name}-pv"
            persistentVolumeClaim = {
                claimName = "${name}-pvc"
            }
        }]
    })

    _service = svc.build_service(svc.ServiceSpec {
        name = name
        namespace = namespace
        port = port
        serviceType = serviceType
        if nodePort:
            nodePort = nodePort
        if portName:
            portName = portName
        labels = {
            app = name
        }
    })

    manifests = [_deployment, _service] + _pv_pvc

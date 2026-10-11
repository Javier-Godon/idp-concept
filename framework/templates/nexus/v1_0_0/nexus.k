"""
Nexus Repository Module Template — Sonatype Nexus Repository 3 with persistent storage.
Generates: PVC (+ optional local PV) + Deployment + Service + HTTPRoute on the platform gateway.

All state (blobs, embedded database, configuration, generated admin password) lives under
/nexus-data, which is backed by a PersistentVolumeClaim, so uploaded artifacts survive restarts.
The Deployment uses the Recreate strategy: the volume is ReadWriteOnce and Nexus must be the only
writer of its data directory.

Usage:
    import framework.templates.nexus.v1_0_0.nexus as nexus

    schema MyNexus(nexus.NexusModule):
        storageSize = "50Gi"
        contextPath = "/nexus"
        route = {hostnames = ["example.com"], path = "/nexus"}
"""
import models.modules.component as component
import builders.deployment as deploy
import builders.service as svc
import builders.storage as storage
import builders.leader as leader
import builders.route as route_builder

NEXUS_IMAGE = "sonatype/nexus3"
NEXUS_DEFAULT_VERSION = "3.96.4"
NEXUS_PORT = 8081
NEXUS_DATA_PATH = "/nexus-data"
# Nexus image runs as the non-root `nexus` user (uid/gid 200).
NEXUS_UID = 200

schema NexusModule(component.Component):
    kind = "APPLICATION"

    storageSize?: str = "50Gi"
    storageClassName?: str
    createLocalPersistentVolume?: bool
    storageHostPath?: str = "/mnt/data"
    serviceType?: str = "ClusterIP"
    # Public sub-path; sets NEXUS_CONTEXT (path without leading '/') so Nexus itself serves under it. Set `route` to publish it.
    contextPath?: str = "/"
    route?: route_builder.RouteSpec
    # JVM heap / direct memory; keep within resources.memoryLimit.
    jvmOptions?: str = "-Xms1g -Xmx1g -XX:MaxDirectMemorySize=1g"
    resources?: deploy.ResourceSpec = deploy.ResourceSpec {
        cpuRequest = "500m"
        cpuLimit = "2"
        memoryRequest = "2Gi"
        memoryLimit = "3Gi"
    }
    imagePullPolicy?: str = "IfNotPresent"
    env?: [any]

    leaders = [leader.build_component_leader(name, namespace)]

    _storage_class = storageClassName if storageClassName != Undefined else (configurations.storageClassName if configurations.storageClassName != Undefined else "rook-ceph-block")
    _create_local_pv = createLocalPersistentVolume if createLocalPersistentVolume != Undefined else (configurations.useLocalPersistentVolumes if configurations.useLocalPersistentVolumes != Undefined else False)
    _context_path = contextPath if contextPath != "/" else ""
    _health_path = "${_context_path}/service/rest/v1/status"

    _pv_pvc = storage.build_pv_and_pvc(storage.PersistentVolumeSpec {
        name = name
        namespace = namespace
        size = storageSize
        storageClassName = _storage_class
        createPersistentVolume = _create_local_pv
        hostPath = "${storageHostPath}/${name}-volume"
    })

    _deployment = deploy.build_deployment(deploy.DeploymentSpec {
        name = name
        namespace = namespace
        image = asset.image if asset.image else NEXUS_IMAGE
        version = asset.version
        port = NEXUS_PORT
        resources = resources
        imagePullPolicy = imagePullPolicy
        strategy = {$type = "Recreate"}
        env = [
            {name = "INSTALL4J_ADD_VM_PARAMS", value = jvmOptions}
            {name = "NEXUS_CONTEXT", value = _context_path[1:]}
        ] + (env or [])
        volumes = [{
            name = "nexus-data"
            persistentVolumeClaim = {claimName = "${name}-pvc"}
        }]
        volumeMounts = [{name = "nexus-data", mountPath = NEXUS_DATA_PATH}]
        podSecurityContext = {
            runAsNonRoot = True
            runAsUser = NEXUS_UID
            runAsGroup = NEXUS_UID
            fsGroup = NEXUS_UID
            seccompProfile = {$type = "RuntimeDefault"}
        }
        containerSecurityContext = {
            allowPrivilegeEscalation = False
            capabilities = {drop = ["ALL"]}
        }
        # First start initializes the repository database and can take several minutes.
        startupProbe = deploy.ProbeSpec {
            probeType = "http"
            path = _health_path
            port = NEXUS_PORT
            initialDelaySeconds = 30
            periodSeconds = 10
            failureThreshold = 60
        }
        readinessProbe = deploy.ProbeSpec {
            probeType = "http"
            path = _health_path
            port = NEXUS_PORT
            initialDelaySeconds = 0
            periodSeconds = 15
        }
        livenessProbe = deploy.ProbeSpec {
            probeType = "http"
            path = _health_path
            port = NEXUS_PORT
            initialDelaySeconds = 0
            periodSeconds = 30
            failureThreshold = 5
        }
    })

    _service = svc.build_service(svc.ServiceSpec {
        name = name
        namespace = namespace
        port = NEXUS_PORT
        serviceType = serviceType
        labels = {app = name}
    })

    _route_list = [route_builder.build_http_route(route_builder.HTTPRouteSpec {
        name = name
        namespace = namespace
        serviceName = name
        servicePort = NEXUS_PORT
        route = route
    })] if route else []

    manifests = _pv_pvc + [_deployment, _service] + _route_list

    check:
        contextPath.startswith("/"), "contextPath must start with '/'"

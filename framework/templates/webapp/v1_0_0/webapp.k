"""
WebApp Module Template — pre-built web application pattern.
Generates: Deployment + Service + ConfigMap (optional) + ServiceAccount (optional).

Usage:
    import framework.templates.webapp as webapp

    schema MyApp(webapp.WebAppModule):
        port = 8080
        serviceType = "NodePort"
        nodePort = 30080
        configData = {"application.yaml" = "server:\\n  port: 8080"}
"""
import models.modules.component as component
import builders.deployment as deploy
import builders.service as svc
import builders.configmap as cm
import builders.service_account as sa
import builders.leader as leader

schema WebAppModule(component.Component):
    kind = "APPLICATION"

    # User-configurable
    port: int
    serviceType?: str = "ClusterIP"
    nodePort?: int
    replicas?: int = 1
    configData?: {str:str}
    configMapKey?: str = "application.yaml"
    configMountPath?: str = "/config/application.yaml"
    imagePullSecretName?: str
    env?: [any]
    resources?: deploy.ResourceSpec
    livenessProbe?: deploy.ProbeSpec
    readinessProbe?: deploy.ProbeSpec
    startupProbe?: deploy.ProbeSpec
    imagePullPolicy?: str = "IfNotPresent"
    extraVolumes?: [any]
    extraVolumeMounts?: [any]

    # Auto-computed
    leaders = [leader.build_component_leader(name, namespace)]

    _sa_name = "${name}-sa" if imagePullSecretName else ""
    _cm_name = "${name}-configmap" if configData else ""

    _deployment = deploy.build_deployment(deploy.DeploymentSpec {
        name = name
        namespace = namespace
        image = asset.image
        version = asset.version
        replicas = replicas
        port = port
        env = env
        resources = resources
        livenessProbe = livenessProbe
        readinessProbe = readinessProbe
        startupProbe = startupProbe
        imagePullPolicy = imagePullPolicy
        if _cm_name:
            configMapRef = _cm_name
            configMapKey = configMapKey
            configMountPath = configMountPath
        if _sa_name:
            serviceAccountName = _sa_name
        volumes = extraVolumes
        volumeMounts = extraVolumeMounts
    })

    _service = svc.build_service(svc.ServiceSpec {
        name = name
        namespace = namespace
        port = port
        serviceType = serviceType
        if nodePort:
            nodePort = nodePort
    })

    _configmap_list = [cm.build_configmap(cm.ConfigMapSpec {
        name = _cm_name
        namespace = namespace
        data = configData
    })] if configData else []

    _sa_list = [sa.build_service_account(sa.ServiceAccountSpec {
        name = _sa_name
        namespace = namespace
        imagePullSecretName = imagePullSecretName
    })] if imagePullSecretName else []

    manifests = [_deployment, _service] + _configmap_list + _sa_list

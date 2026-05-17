"""
Acceptance fixture: basic Kubernetes workload generated through framework builders.

This is intentionally tiny and suitable for a default kind smoke test.
"""

import manifests
import builders.configmap as cm
import builders.deployment as deploy
import builders.service as svc

_namespace = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {name = "idp-acceptance-basic"}
}

_configmap = cm.build_configmap(cm.ConfigMapSpec {
    name = "acceptance-config"
    namespace = "idp-acceptance-basic"
    data = {"config.yaml" = "message: acceptance\n"}
})

_deployment = deploy.build_deployment(deploy.DeploymentSpec {
    name = "acceptance-pause"
    namespace = "idp-acceptance-basic"
    image = "registry.k8s.io/pause"
    version = "3.10"
    replicas = 1
    port = 8080
    configMapRef = "acceptance-config"
    configMapKey = "config.yaml"
    configMountPath = "/config/config.yaml"
    resources = deploy.ResourceSpec {
        cpuRequest = "10m"
        cpuLimit = "50m"
        memoryRequest = "32Mi"
        memoryLimit = "64Mi"
    }
})

_service = svc.build_service(svc.ServiceSpec {
    name = "acceptance-pause"
    namespace = "idp-acceptance-basic"
    port = 8080
    targetPort = 8080
    serviceType = "ClusterIP"
})

manifests.yaml_stream([_namespace, _configmap, _deployment, _service])


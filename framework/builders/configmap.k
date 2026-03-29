"""
ConfigMap Builder — generates a Kubernetes ConfigMap from a high-level spec.
"""
import k8s.api.core.v1 as core

schema ConfigMapSpec:
    name: str
    namespace: str
    data: {str:str}

build_configmap = lambda spec: ConfigMapSpec -> core.ConfigMap {
    core.ConfigMap {
        apiVersion = "v1"
        kind = "ConfigMap"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        data = spec.data
    }
}

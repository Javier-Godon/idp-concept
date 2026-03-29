"""
ServiceAccount Builder — generates a Kubernetes ServiceAccount with optional imagePullSecrets.
"""
import k8s.api.core.v1 as core

schema ServiceAccountSpec:
    name: str
    namespace: str
    imagePullSecretName?: str

build_service_account = lambda spec: ServiceAccountSpec -> core.ServiceAccount {
    core.ServiceAccount {
        apiVersion = "v1"
        kind = "ServiceAccount"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        if spec.imagePullSecretName:
            imagePullSecrets = [{
                name = spec.imagePullSecretName
            }]
    }
}

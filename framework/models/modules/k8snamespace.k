import k8s.api.core.v1 as k8core
import k8s.api.apps.v1 as k8sapps

schema K8sNamespaceLeader:
    name: str
    kind: str
    apiVersion: str
    namespace?: str

schema K8sNamespaceInstance:
    name: str
    kind: str
    apiVersion: str
    configurations: any
    leaders: [K8sNamespaceLeader]
    manifests: [any]
    dependsOn: [any] = []

schema K8sNamespace:
    instance: K8sNamespaceInstance = K8sNamespaceInstance {
        name = name
        kind = kind
        apiVersion = apiVersion
        configurations = configurations
        leaders = leaders
        manifests = manifests
    }
    kind: str = "Namespace"
    name: str
    apiVersion: str = "v1"
    configurations: any
    annotations?: {str:str}
    labels?: {str:str}
    leaders: [K8sNamespaceLeader] = [K8sNamespaceLeader {
        name = name
        kind = kind
        apiVersion = apiVersion
    }]
    manifests: [k8core.Namespace] = [k8core.Namespace {
        apiVersion = apiVersion
        kind = "Namespace"
        metadata = {
            name = name
            annotations = annotations
            labels = labels
        }
    }]


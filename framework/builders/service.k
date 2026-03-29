"""
Service Builder — generates a Kubernetes Service from a high-level spec.
"""
import k8s.api.core.v1 as core

schema ServiceSpec:
    name: str
    namespace: str
    port: int
    targetPort?: int
    nodePort?: int
    serviceType?: str = "ClusterIP"
    portName?: str
    labels?: {str:str}

build_service = lambda spec: ServiceSpec -> core.Service {
    _port_entry = {
        port = spec.port
        if spec.portName:
            name = spec.portName
        if spec.targetPort:
            targetPort = spec.targetPort
        if spec.nodePort:
            nodePort = spec.nodePort
    }
    core.Service {
        apiVersion = "v1"
        kind = "Service"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            if spec.labels:
                labels = spec.labels
        }
        spec = {
            selector = {
                app = spec.name
            }
            ports = [_port_entry]
            $type = spec.serviceType
        }
    }
}

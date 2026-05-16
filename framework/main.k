import models.stack as stack
import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as k8snamespace

_config = {}
_ns = k8snamespace.K8sNamespace {
    name = "dev"
    configurations = _config
}.instance

minimal_stack = stack.Stack {
    instanceConfigurations = _config
    components = [
        component.ComponentInstance {
            name = "producer"
            kind = "APPLICATION"
            namespace = _ns.name
            configurations = _config
            asset = {version = "0.0.1"}
            leaders = [component.ComponentLeader {
                name = "producer"
                kind = "Deployment"
                apiVersion = "apps/v1"
                namespace = _ns.name
            }]
            manifests = [{}]
            dependsOn = [_ns]
        }
    ]
    accessories = [
        accessory.AccessoryInstance {
            name = "producer-db"
            kind = "CRD"
            namespace = _ns.name
            configurations = _config
            asset = {version = "0.0.1"}
            leaders = [accessory.AccessoryLeader {
                name = "producer-db"
                kind = "StatefulSet"
                apiVersion = "apps/v1"
                namespace = _ns.name
            }]
            manifests = [{}]
            dependsOn = [_ns]
        }
    ]
    k8snamespaces = [_ns]
}

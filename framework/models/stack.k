import models.component
import models.accessory
import models.k8snamespace

schema Stack:
    name: str
    components: [component.Component]
    accesories?: [accessory.Accessory]
    k8snamespaces?: [k8snamespace.K8sNamespace]


import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.modules.thirdparty
import models.metadata as meta

schema StackInstance:
    # framework-generic: accepts any project config schema (merged from all layers)
    instanceConfigurations: any
    metadata?: meta.Metadata
    components: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdParty]    

schema Stack:
    instance: StackInstance = StackInstance {
        instanceConfigurations = instanceConfigurations
        metadata = metadata
        components = components
        accessories = accessories
        k8snamespaces = k8snamespaces
        thirdParties = thirdParties
    }
    # framework-generic: accepts any project config schema (merged from all layers)
    instanceConfigurations: any
    metadata?: meta.Metadata
    components: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdParty]


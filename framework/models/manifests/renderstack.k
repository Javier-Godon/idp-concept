import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.modules.thirdparty

schema RenderStackInstance:
    instanceConfigurations: any
    components?: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdPartyInstance]

schema RenderStack:
    instance: RenderStackInstance = RenderStackInstance {
        instanceConfigurations = instanceConfigurations
        accessories = accessories
        k8snamespaces = k8snamespaces
        thirdParties = thirdParties
    }

    instanceConfigurations: any
    components?: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdPartyInstance]


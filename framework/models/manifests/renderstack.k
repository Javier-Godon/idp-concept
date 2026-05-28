import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.modules.thirdparty
import models.release_notes as rn

schema RenderStackInstance:
    instanceConfigurations: any
    components?: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdPartyInstance]
    releaseNotes?: rn.ReleaseNotes

schema RenderStack:
    instance: RenderStackInstance = RenderStackInstance {
        instanceConfigurations = instanceConfigurations
        components = components
        accessories = accessories
        k8snamespaces = k8snamespaces
        thirdParties = thirdParties
        releaseNotes = releaseNotes
    }

    instanceConfigurations: any
    components?: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdPartyInstance]
    releaseNotes?: rn.ReleaseNotes


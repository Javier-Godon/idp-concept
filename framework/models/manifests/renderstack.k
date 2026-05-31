import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.modules.thirdparty
import models.metadata as meta
import models.release_notes as rn
import custom.helmfile.helmfile as hf

schema RenderStackInstance:
    instanceConfigurations: any
    components?: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdPartyInstance]
    metadata?: meta.Metadata
    releaseNotes?: rn.ReleaseNotes
    helmfile?: hf.HelmfileRenderOptions

schema RenderStack:
    instance: RenderStackInstance = RenderStackInstance {
        instanceConfigurations = instanceConfigurations
        components = components
        accessories = accessories
        k8snamespaces = k8snamespaces
        thirdParties = thirdParties
        metadata = metadata
        releaseNotes = releaseNotes
        helmfile = helmfile
    }

    instanceConfigurations: any
    components?: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdPartyInstance]
    metadata?: meta.Metadata
    releaseNotes?: rn.ReleaseNotes
    helmfile?: hf.HelmfileRenderOptions


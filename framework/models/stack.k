import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.profile as fmwk_profile
import models.site as fmwk_site
import configs.configurations
import configs.models.kernel_config

schema StackInstance:
    profile: fmwk_profile.Profile
    kernelConfigurations: kernel_config.KernelConfig
    site: fmwk_site.SiteInstance
    components: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]

schema Stack:
    instance: StackInstance = StackInstance {
        profile = profile
        kernelConfigurations = kernelConfigurations
        site = site
        components = components
        accessories = accessories
        k8snamespaces = k8snamespaces
    }
    profile: fmwk_profile.Profile
    kernelConfigurations: kernel_config.KernelConfig
    site: fmwk_site.SiteInstance
    components: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]


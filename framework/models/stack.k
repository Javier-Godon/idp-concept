import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.modules.thirdparty
import models.profile as fmwk_profile
import models.project as fmwk_project
import models.site as fmwk_site

schema StackInstance:
    profile: fmwk_profile.ProfileInstance
    project: fmwk_project.ProjectInstance
    site: fmwk_site.SiteInstance
    components: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdParty]

schema Stack:
    instance: StackInstance = StackInstance {
        profile = profile
        project: project
        site = site
        components = components
        accessories = accessories
        k8snamespaces = k8snamespaces
        thirdParties = thirdParties
    }
    profile: fmwk_profile.ProfileInstance
    project: fmwk_project.ProjectInstance
    site: fmwk_site.SiteInstance
    components: [component.ComponentInstance]
    accessories?: [accessory.AccessoryInstance]
    k8snamespaces?: [k8snamespace.K8sNamespaceInstance]
    thirdParties?: [thirdparty.ThirdParty]


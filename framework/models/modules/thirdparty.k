"""
Represents the specific configurations in the specific format of a third party app deployed as indicated for the provider 
(it will use a concrete package manager, like for example and usually Helm)
For example. If it uses helm as package manager, the helm chart is given for a concrete version and the only adaptation we have to keep configurable
and declarative for our part will be the values.yaml, those concrete values depend on the vendor (vendorConfigurations)
those vendorConfigurations are fill in depending on the platforConfigurations that are specific for your platform
"""
import configs.configurations as configs

schema ThirdPartyInstance:
    packageManager: str
    platformConfigurations: configs.Configurations
    vendorConfigurations: {str:str}

schema ThirdParty:
    instance = ThirdPartyInstance {
        packageManager = packageManager
        platformConfigurations = platformConfigurations
        vendorConfigurations = vendorConfigurations
    }
    packageManager: "HELM" | "JSONNET" | "KUSTOMIZE" | "TIMONI" | "KUSION"
    platformConfigurations: configs.Configurations
    vendorConfigurations: {str:str}


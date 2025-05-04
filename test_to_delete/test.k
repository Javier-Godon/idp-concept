schema Configurations:
    appsNamespace?: str
    postgresNamespace?: str
    certmanagerNamespace?: str
    apacheKafkaNamespace?: str
    mongodbNamespace?: str

# configs:  Configurations {
#     appsNamespace = "kernelNamespace"
#     apacheKafkaNamespace= "kernelNamespace"   
# }
# configs:  Configurations {
#     appsNamespace="profileNamespace"
#     certmanagerNamespace= "profileNamespace"
# }
# configs:  Configurations {
#     appsNamespace="siteNamespace"
#     postgresNamespace="siteNamespace"
#     mongodbNamespace="siteNamespace"
# }
# schema MergedConfigurations:
#     kernel: Configurations
#     profile: Configurations
#     site: Configurations
#     configurations: Configurations = merge_configurations(kernel,profile,site)

#     configs: Configurations = kernel
#     configs: Configurations = configs | profile
#     configs: Configurations = configs | site
# configs = MergedConfigurations {
#     kernel = Configurations {
#         appsNamespace = "kernelNamespace"
#         apacheKafkaNamespace = "kernelNamespace"
#     }
#     profile = Configurations {
#         appsNamespace = "kernelNamespace"
#         certmanagerNamespace= "profileNamespace"
#     }
#     site = Configurations {
#         appsNamespace = "kernelNamespace"
#         postgresNamespace="siteNamespace"
#         mongodbNamespace="siteNamespace"
#     }
# }.configs
_kernel = Configurations {
    appsNamespace = "kernelNamespace"
    apacheKafkaNamespace = "kernelNamespace"
}
_profile = Configurations {
    appsNamespace = "kernelNamespace"
    certmanagerNamespace = "profileNamespace"
}
_site = Configurations {
    appsNamespace = "kernelNamespace"
    postgresNamespace = "siteNamespace"
    mongodbNamespace = "siteNamespace"
}

# configurations = MergedConfigurations{
#     kernel= _kernel
#     profile = _profile
#     site = _site
# }.configurations



_configurations: Configurations{
    appsNamespace = "kernelNamespace"
    postgresNamespace = "siteNamespace"
    mongodbNamespace = "siteNamespace"
}

_configurations: Configurations{
}



# configurations = _configurations



# coinfigurations = merge_configurations(_kernel,_profile,_site)

merge_configurations = lambda kernelConfigurations: Configurations, profileConfigurations: Configurations, siteConfigurations: Configurations -> Configurations {
    configs: Configurations = kernelConfigurations
    configs: Configurations = configs | profileConfigurations
    configs: Configurations = configs | siteConfigurations
}

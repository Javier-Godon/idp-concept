# schema Configurations:
#     appsNamespace?: str
#     postgresNamespace?: str
#     certmanagerNamespace?: str
#     apacheKafkaNamespace?: str
#     mongodbNamespace?: str


# schema KernelConfig:
#      configurations: Configurations

# _kernelConfigs: KernelConfig{
#     configurations.appsNamespace = "kernelNamespace"
#     configurations.apacheKafkaNamespace = "kernelNamespace"
# }     

# schema ProfileConfig:
#     configurations: Configurations

# _profileConfigs: ProfileConfig{
#     configurations.appsNamespace = "profileNamespace"
#     configurations.certmanagerNamespace = "profileNamespace"
# }     

# schema SiteConfig:
#     configurations: Configurations

# _siteConfigs: SiteConfig{
#     configurations.appsNamespace = "siteNamespace"
#     configurations.mongodbNamespace = "siteNamespace"
#     configurations.postgresNamespace = "siteNamespace"
# } 
# variable: str = "appsNamespace"   

# configs:  Configurations {
#     if _kernelConfigs.configurations.appsNamespace:
#         appsNamespace = _kernelConfigs.configurations.appsNamespace
#     if _kernelConfigs.configurations.postgresNamespace:
#         postgresNamespace = _kernelConfigs.configurations.postgresNamespace
#     if _kernelConfigs.configurations.certmanagerNamespace:
#         certmanagerNamespace = _kernelConfigs.configurations.certmanagerNamespace
#     if _kernelConfigs.configurations.apacheKafkaNamespace:
#         apacheKafkaNamespace = _kernelConfigs.configurations.apacheKafkaNamespace
#     if _kernelConfigs.configurations.mongodbNamespace:
#         mongodbNamespace = _kernelConfigs.configurations.mongodbNamespace
# }

# configs:  Configurations {
#     if _profileConfigs.configurations.appsNamespace:
#         appsNamespace = _profileConfigs.configurations.appsNamespace
#     if _profileConfigs.configurations.postgresNamespace:
#         postgresNamespace = _profileConfigs.configurations.postgresNamespace
#     if _profileConfigs.configurations.certmanagerNamespace:
#         certmanagerNamespace = _profileConfigs.configurations.certmanagerNamespace
#     if _profileConfigs.configurations.apacheKafkaNamespace:
#         apacheKafkaNamespace = _profileConfigs.configurations.apacheKafkaNamespace
#     if _profileConfigs.configurations.mongodbNamespace:
#         mongodbNamespace = _profileConfigs.configurations.mongodbNamespace
# }

# configs:  Configurations {
#     if _siteConfigs.configurations.appsNamespace:
#         appsNamespace = _siteConfigs.configurations.appsNamespace
#     if _siteConfigs.configurations.postgresNamespace:
#         postgresNamespace = _siteConfigs.configurations.postgresNamespace
#     if _siteConfigs.configurations.certmanagerNamespace:
#         certmanagerNamespace = _siteConfigs.configurations.certmanagerNamespace
#     if _siteConfigs.configurations.apacheKafkaNamespace:
#         apacheKafkaNamespace = _siteConfigs.configurations.apacheKafkaNamespace
#     if _siteConfigs.configurations.mongodbNamespace:
#         mongodbNamespace = _siteConfigs.configurations.mongodbNamespace
# }


schema VideoStreamingConfigurations:
    projectName?: str = "video_streaming"
    brandIcon?: str
    siteName?: str
    appsNamespace?: str
    postgresNamespace?: str
    certmanagerNamespace?: str
    apacheKafkaNamespace?: str
    mongodbNamespace?: str
    rootPaths?: {str:str}

# merge_configurations = lambda kernelConfigurations: VideoStreamingConfigurations, profileConfigurations: VideoStreamingConfigurations, tenantConfigurations: VideoStreamingConfigurations,siteConfigurations: VideoStreamingConfigurations -> VideoStreamingConfigurations {
#     configs: VideoStreamingConfigurations = kernelConfigurations
#     configs: VideoStreamingConfigurations = configs | profileConfigurations
#     configs: VideoStreamingConfigurations = configs | tenantConfigurations
#     configs: VideoStreamingConfigurations = configs | siteConfigurations
# }

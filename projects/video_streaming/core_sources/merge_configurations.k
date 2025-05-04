import video_streaming_configurations as configurations

merge_configurations = lambda kernelConfigurations: configurations.VideoStreamingConfigurations, profileConfigurations: configurations.VideoStreamingConfigurations, tenantConfigurations: configurations.VideoStreamingConfigurations, siteConfigurations: configurations.VideoStreamingConfigurations -> configurations.VideoStreamingConfigurations {
    _configs: configurations.VideoStreamingConfigurations =  kernelConfigurations
    _configs: configurations.VideoStreamingConfigurations = _configs | profileConfigurations
    _configs: configurations.VideoStreamingConfigurations = _configs | tenantConfigurations
    _configs: configurations.VideoStreamingConfigurations = _configs | siteConfigurations
}

import video_streaming.core_sources.video_streaming_configurations
import sites_configurations
import file
import yaml

path = file.current().replace("configurations.k", "", count=0)
data_from_yaml = yaml.decode(file.read(path + "config.yaml"))
# _video_streaming_site_configurations = sites_configurations._video_streaming_site_configurations
_video_streaming_site_configurations: video_streaming_configurations.VideoStreamingConfigurations {
    siteName = data_from_yaml.site.name
    rootPaths = {
        "local opensearch": data_from_yaml.rootPaths.localOpensearch
        "central opensearch": data_from_yaml.rootPaths.centralOpensearch
        "keycloak": data_from_yaml.rootPaths.keycloak
    }
}

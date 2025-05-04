import video_streaming.core_sources.video_streaming_configurations
import sites_configurations

# _video_streaming_site_configurations = sites_configurations._video_streaming_site_configurations

_video_streaming_site_configurations: video_streaming_configurations.VideoStreamingConfigurations {
    siteName = "Berlin"
    rootPaths = {
        "local opensearch": "http://opensearch.opensearch"
        "central opensearch": "https://central-services/opensearch"
        "keycloak": "keycloak.keycloak/realm/auth"
    }
}


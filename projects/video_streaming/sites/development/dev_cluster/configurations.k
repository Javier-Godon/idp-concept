import video_streaming.core_sources.video_streaming_configurations
import video_streaming.sites.sites_configurations

_dev_cluster_site_configurations = sites_configurations._video_streaming_site_configurations

_dev_cluster_site_configurations = video_streaming_configurations.VideoStreamingConfigurations{
    siteName = "dev cluster"
    rootPaths = {
        "local opensearch": "http://opensearch.opensearch"
    }
}
import video_streaming.core_sources.video_streaming_configurations
import stack_configurations

_video_streaming_profile_configurations = stack_configurations._video_streaming_profile_configurations

_video_streaming_profile_configurations: video_streaming_configurations.VideoStreamingConfigurations {
    appsNamespace = "apps"
    postgresNamespace = "postgres"
}

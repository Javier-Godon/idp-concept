import framework.models.profile
import video_streaming.core_sources.video_streaming_configurations
import video_streaming.stacks.development.profile_configurations

video_streaming_development_profile = profile.Profile {
    name = "development"
    configurations = video_streaming_configurations.VideoStreamingConfigurations {
        **profile_configurations._video_streaming_profile_configurations
    }
}

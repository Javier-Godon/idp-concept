import framework.models.profile
import video_streaming.core_sources.video_streaming_configurations
import versioned.v1_0_0.base.profile_configurations

video_streaming_v1_0_0_base_profile = profile.Profile {
    name = "v1_0_0"
    configurations = video_streaming_configurations.VideoStreamingConfigurations {
        **profile_configurations._video_streaming_profile_configurations
    }
}

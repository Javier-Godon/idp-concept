import framework.models.profile
import versioned.v1_0_0.base.profile_configurations

video_streaming_v1_0_0_base_profile = profile.Profile {
    name = "v1_0_0"
    configurations = profile_configurations._video_streaming_profile_configurations
}

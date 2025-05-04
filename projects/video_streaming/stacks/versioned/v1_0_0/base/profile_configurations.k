import video_streaming.core_sources.video_streaming_configurations
import stack_configurations

# This works for each layer, but when I merge the configurations, it takes only the firs assigned value and brakes everything.
# So we cannot apply general stack configurations, add this ones and them merge them with the rest of configurations: project, site,..
# _video_streaming_profile_configurations = stack_configurations._video_streaming_profile_configurations

_video_streaming_profile_configurations: video_streaming_configurations.VideoStreamingConfigurations {
    appsNamespace = "apps"
    postgresNamespace = "postgres"
    certmanagerNamespace = "cert-manager"
}

import framework.models.site
import tenants.germany
import video_streaming.core_sources.video_streaming_configurations

berlin_stie = site.Site {
    name = "Berlin"
    tenant = germany.tenant_germany
    configurations = video_streaming_configurations.VideoStreamingConfigurations {
        **_video_streaming_site_configurations
    }
}

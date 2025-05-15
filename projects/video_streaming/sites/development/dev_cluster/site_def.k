import framework.models.site
import video_streaming.tenants.vendor
import video_streaming.core_sources.video_streaming_configurations
import video_streaming.sites.development.dev_cluster.configurations

dev_cluster_site = site.Site {
    name = "dev_cluster"
    tenant = vendor.tenant_vendor
    configurations = video_streaming_configurations.VideoStreamingConfigurations {
        **configurations._dev_cluster_site_configurations
    }
}

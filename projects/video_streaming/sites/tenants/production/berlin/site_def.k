import framework.models.site
import tenants.germany

berlin_stie = site.Site {
    name = "Berlin"
    tenant = germany.tenant_germany
    configurations = berlin_config
}

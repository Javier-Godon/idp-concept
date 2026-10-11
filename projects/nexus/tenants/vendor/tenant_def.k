import file
import framework.factory.conventions as conventions
import nexus.core_sources.nexus_configurations as cfg

tenant = conventions.build_tenant(conventions.TenantSpec {
    currentFile = file.current()
    name = "Internal"
    description = "Internal vendor/development team"
    configurations = cfg.NexusConfigurations {
        brandIcon = "internal-logo"
    }
})

tenant_vendor = tenant

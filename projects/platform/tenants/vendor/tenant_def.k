import file
import framework.factory.conventions as conventions
import platform.core_sources.platform_configurations as cfg

tenant = conventions.build_tenant(conventions.TenantSpec {
    currentFile = file.current()
    name = "Internal"
    description = "Internal vendor/development team"
    configurations = cfg.PlatformConfigurations {
        brandIcon = "internal-logo"
    }
})

tenant_vendor = tenant

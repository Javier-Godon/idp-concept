import file
import framework.factory.conventions as conventions
import platform.core_sources.platform_configurations as cfg
import platform.stacks.development.profile_configurations

profile = conventions.build_profile(conventions.ProfileSpec {
    currentFile = file.current()
    configurations = cfg.PlatformConfigurations {
        **profile_configurations._platform_profile_configurations
    }
})

platform_development_profile = profile

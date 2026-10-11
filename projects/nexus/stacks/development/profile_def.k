import file
import framework.factory.conventions as conventions
import nexus.core_sources.nexus_configurations as cfg
import nexus.stacks.development.profile_configurations

profile = conventions.build_profile(conventions.ProfileSpec {
    currentFile = file.current()
    configurations = cfg.NexusConfigurations {
        **profile_configurations._nexus_profile_configurations
    }
})

nexus_development_profile = profile

import file
import framework.factory.conventions as conventions
import nexus.core_sources.nexus_configurations as cfg

_nexus_kernel_configurations = cfg.NexusConfigurations {
    projectName = conventions.project_slug_from_path(file.current())
    gitRepoUrl = "https://github.com/Javier-Godon/idp-concept.git"
    backstageOwner = "platform-team"
}

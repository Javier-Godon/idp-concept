import file
import framework.factory.conventions as conventions
import platform.core_sources.platform_configurations as cfg

_platform_kernel_configurations = cfg.PlatformConfigurations {
    projectName = conventions.project_slug_from_path(file.current())
    gitRepoUrl = "https://github.com/Javier-Godon/idp-concept.git"
    backstageOwner = "platform-team"
}

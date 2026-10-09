import file
import framework.factory.conventions as conventions
import erp.core_sources.erp_configurations as cfg

_erp_kernel_configurations = cfg.ErpConfigurations {
    projectName = conventions.project_slug_from_path(file.current())
    gitRepoUrl = "https://github.com/Javier-Godon/idp-concept.git"
    backstageOwner = "erp-team"
}

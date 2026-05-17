import file
import framework.factory.conventions as conventions
import erp_back.core_sources.erp_back_configurations

_erp_back_kernel_configurations = erp_back_configurations.ErpBackConfigurations {
    projectName = conventions.project_slug_from_path(file.current())
    postgresDatabase = "erp_db"
    storageClassName = "rook-ceph-block"
    gitRepoUrl = "https://github.com/Javier-Godon/idp-concept"
}

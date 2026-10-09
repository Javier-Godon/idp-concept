import file
import framework.factory.conventions as conventions
import erp.core_sources.erp_configurations as cfg
import erp.stacks.development.profile_configurations

profile = conventions.build_profile(conventions.ProfileSpec {
    currentFile = file.current()
    configurations = cfg.ErpConfigurations {
        **profile_configurations._erp_profile_configurations
    }
})

erp_development_profile = profile

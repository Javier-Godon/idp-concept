import file
import framework.factory.conventions as conventions
import erp_back.core_sources.erp_back_configurations
import erp_back.stacks.versioned.v1_0_0.profile_configurations

profile = conventions.build_profile(conventions.ProfileSpec {
    currentFile = file.current()
    configurations = erp_back_configurations.ErpBackConfigurations {
        **profile_configurations._erp_back_v1_0_0_profile_configurations
    }
})

erp_back_v1_0_0_profile = profile


import framework.models.profile
import erp_back.core_sources.erp_back_configurations
import erp_back.stacks.versioned.v1_0_0.profile_configurations

erp_back_v1_0_0_profile = profile.Profile {
    name = "v1_0_0"
    configurations = erp_back_configurations.ErpBackConfigurations {
        **profile_configurations._erp_back_v1_0_0_profile_configurations
    }
}

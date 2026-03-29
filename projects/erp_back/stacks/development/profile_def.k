import framework.models.profile
import erp_back.core_sources.erp_back_configurations
import erp_back.stacks.development.profile_configurations

erp_back_development_profile = profile.Profile {
    name = "development"
    configurations = erp_back_configurations.ErpBackConfigurations {
        **profile_configurations._erp_back_profile_configurations
    }
}

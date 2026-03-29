"""
Configuration merge function for erp_back.
Uses the framework's generic merge_configurations.
"""
import framework.models.configurations as base
import erp_back.core_sources.erp_back_configurations as configurations

merge_configurations = lambda kernelConfigurations: configurations.ErpBackConfigurations, profileConfigurations: configurations.ErpBackConfigurations, tenantConfigurations: configurations.ErpBackConfigurations, siteConfigurations: configurations.ErpBackConfigurations -> configurations.ErpBackConfigurations {
    base.merge_configurations(kernelConfigurations, profileConfigurations, tenantConfigurations, siteConfigurations)
}

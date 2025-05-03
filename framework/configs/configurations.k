import configs.models.kernel_config as kernel_config
import configs.models.site_config as site_config
import configs.models.profile_config as profile_config

schema Configurations:
    kernelConfigurations: kernel_config.KernelConfig
    siteConfigurations: site_config.SiteConfig
    profileConfigurations: profile_config.ProfileConfig


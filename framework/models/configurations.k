"""
Base configuration schema and generic merge function.
Projects extend BaseConfigurations with project-specific fields and reuse the merge function.

Usage:
    import framework.models.configurations as base

    schema MyProjectConfigurations(base.BaseConfigurations):
        myCustomField?: str

    # Merge: kernel | profile | tenant | site
    _merged = base.merge_configurations(kernel_cfg, profile_cfg, tenant_cfg, site_cfg)
"""

schema BaseConfigurations:
    projectName?: str
    siteName?: str
    brandIcon?: str
    appsNamespace?: str
    rootPaths?: {str:str}

merge_configurations = lambda kernel: any, profile: any, tenant: any, site: any -> any {
    _configs = kernel
    _configs = _configs | profile
    _configs = _configs | tenant
    _configs = _configs | site
}

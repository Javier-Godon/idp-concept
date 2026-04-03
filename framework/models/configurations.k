"""
Base configuration schema and generic merge function.
Projects extend BaseConfigurations with project-specific fields and reuse the merge function.

Configuration Merge Order:
    1. kernel   — project-wide defaults (e.g. project name, git repo)
    2. profile  — deployment profile (e.g. dev resources, prod replicas)
    3. tenant   — customer-specific overrides (e.g. branding, feature flags)
    4. site     — environment-specific overrides (e.g. hostnames, storage class)

Later layers override earlier ones via the KCL union operator (|).

Usage:
    import framework.models.configurations as base

    schema MyProjectConfigurations(base.BaseConfigurations):
        myCustomField?: str

    # Merge: kernel | profile | tenant | site
    _merged = base.merge_configurations(kernel_cfg, profile_cfg, tenant_cfg, site_cfg)
"""

schema BaseConfigurations:
    """Fields common to all projects. Extend this with project-specific settings."""
    projectName?: str
    siteName?: str
    brandIcon?: str
    appsNamespace?: str
    gitRepoUrl?: str
    rootPaths?: {str:str}
    backstageOwner?: str
    backstageSystem?: str
    backstageLifecycle?: str

# framework-generic: accepts any project config schema — each layer may be a different project-specific type
merge_configurations = lambda kernel: any, profile: any, tenant: any, site: any -> any {
    kernel | profile | tenant | site
}

"""
erp project-specific configuration schema.
Extends BaseConfigurations with project-specific fields.
"""

import framework.models.configurations as base

schema ErpConfigurations(base.BaseConfigurations):
    cacheNamespace?: str
    footprint?: "local" | "development" | "staging" | "production"

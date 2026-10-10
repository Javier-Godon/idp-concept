"""
erp project-specific configuration schema.
Extends BaseConfigurations with project-specific fields.
"""

import framework.models.configurations as base

schema ErpConfigurations(base.BaseConfigurations):
    cacheNamespace?: str
    postgresNamespace?: str
    postgresFootprint?: "local" | "development" | "staging" | "production"
    postgresDatabase?: str
    postgresSuperuserSecret?: str
    postgresNodePort?: int
    footprint?: "local" | "development" | "staging" | "production"

"""
ERP Back project-specific configuration schema.
Extends BaseConfigurations with project-specific fields.
"""
import framework.models.configurations as base

schema ErpBackConfigurations(base.BaseConfigurations):
    postgresNamespace?: str
    postgresHost?: str
    postgresPort?: int = 5432
    postgresDatabase?: str = "erp_db"
    springProfile?: str = "default"
    javaOpts?: str = "-Xmx1g -Xms512m"

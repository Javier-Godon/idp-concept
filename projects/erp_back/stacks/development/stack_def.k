"""
ERP Back development stack — defines what modules are deployed together.
Uses framework assembly helpers to reduce namespace boilerplate.
"""
import framework.models.modules.k8snamespace as k8snamespace
import framework.models.stack
import framework.assembly.helpers as asm
import erp_back.modules.appops.erp_api.erp_api_module_def as erp_api
import erp_back.modules.infrastructure.postgres.postgres_module_def as postgres

schema ErpBackDevelopmentStack(stack.Stack):
    # Namespaces
    _apps_namespace = asm.create_namespace(instanceConfigurations.appsNamespace, instanceConfigurations)
    _postgres_namespace = asm.create_namespace(instanceConfigurations.postgresNamespace, instanceConfigurations)

    k8snamespaces = [
        _apps_namespace
        _postgres_namespace
    ]

    # Components
    _erp_api = erp_api.ErpApiModule {
        name = "erp-api"
        namespace = _apps_namespace.name
        asset = {
            image = "ghcr.io/javier-godon/erp-back-api"
            version = "1.0.0"
        }
        configurations = instanceConfigurations
        dependsOn = [_apps_namespace]
    }.instance

    components = [_erp_api]

    # Accessories
    _postgres = postgres.PostgresModule {
        name = "erp-postgres"
        namespace = _postgres_namespace.name
        asset = {
            image = "postgres"
            version = "16.4-alpine"
        }
        configurations = instanceConfigurations
        dependsOn = [_postgres_namespace]
    }.instance

    accessories = [_postgres]

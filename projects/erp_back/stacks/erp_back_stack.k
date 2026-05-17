"""
Shared ERP Back stack template.

Versioned/development stack folders should only override the values that differ
between profiles (for example image tags or resource sizing); the common
namespace and module wiring lives here.
"""

import framework.models.stack
import framework.assembly.helpers as asm
import erp_back.modules.appops.erp_api.erp_api_module_def as erp_api
import erp_back.modules.infrastructure.postgres.postgres_module_def as postgres

schema ErpBackStack(stack.Stack):
    erpApiImage: str = "ghcr.io/javier-godon/erp-back-api"
    erpApiVersion: str = "1.0.0"
    postgresImage: str = "postgres"
    postgresVersion: str = "16.4-alpine"

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
            image = erpApiImage
            version = erpApiVersion
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
            image = postgresImage
            version = postgresVersion
        }
        configurations = instanceConfigurations
        dependsOn = [_postgres_namespace]
    }.instance

    accessories = [_postgres]


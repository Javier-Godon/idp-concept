"""
Backstage Template — Developer portal deployed via official Backstage Helm chart.

Backstage (CNCF Incubation, Apache-2.0) is a developer portal providing a service
catalog, software templates (scaffolder), TechDocs, and plugin ecosystem.

Helm chart: https://github.com/backstage/charts
Chart repo: https://backstage.github.io/charts (chart: backstage/backstage)
PostgreSQL: Uses CloudNativePG from framework/templates/postgresql.k

Usage:
    import templates.backstage as bs

    _spec = bs.BackstageHelmSpec {
        name = "backstage"
        namespace = "backstage"
        host = "backstage.example.com"
        catalogLocations = ["https://github.com/org/repo/blob/main/catalog-info.yaml"]
    }
    _manifest = bs.build_backstage_release(_spec)

    # With PostgreSQL via CloudNativePG:
    import templates.postgresql as pg

    _pg_spec = pg.CNPGClusterSpec {
        name = "backstage-db"
        namespace = "backstage"
        instances = 2
        storageSize = "10Gi"
    }
    _pg_manifest = pg.build_cnpg_cluster(_pg_spec)
"""
import models.modules.thirdparty_helm as th

schema BackstageHelmSpec:
    """Specification for deploying Backstage via the official Helm chart."""
    name: str
    namespace: str
    chartVersion: str = "2.3.0"
    host?: str

    # PostgreSQL connection (external DB recommended — use CloudNativePG template)
    postgresHost?: str
    postgresPort: int = 5432
    postgresUser: str = "backstage"
    postgresSecretName?: str
    postgresSecretKey: str = "password"

    # Catalog configuration
    catalogLocations?: [str]

    # Auth provider
    authProvider?: str

    # TechDocs
    techdocsBuilder: str = "local"
    techdocsGeneratorType: str = "mkdocs"

    # Resource requests/limits
    cpuRequest?: str
    memoryRequest?: str
    cpuLimit?: str
    memoryLimit?: str

    # Replicas
    replicas: int = 1

    # Extra Helm values (flat key=value)
    extraValues?: {str:str}

    check:
        len(name) > 0, "Backstage release name must not be empty"
        len(namespace) > 0, "Backstage namespace must not be empty"
        replicas >= 1, "Backstage replicas must be >= 1"

build_backstage_release = lambda spec: BackstageHelmSpec -> any {
    """Build a Backstage Helm release manifest."""
    _base_values: {str:str} = {
        "backstage.replicas" = str(spec.replicas)
        "backstage.appConfig.app.baseUrl" = "https://${spec.host or 'backstage.local'}"
        "backstage.appConfig.backend.baseUrl" = "https://${spec.host or 'backstage.local'}"
    }

    _postgres_values: {str:str} = {
        "postgresql.enabled" = "false"
        if spec.postgresHost:
            "backstage.appConfig.backend.database.client" = "pg"
            "backstage.appConfig.backend.database.connection.host" = spec.postgresHost
            "backstage.appConfig.backend.database.connection.port" = str(spec.postgresPort)
            "backstage.appConfig.backend.database.connection.user" = spec.postgresUser
        if spec.postgresSecretName:
            "backstage.appConfig.backend.database.connection.password.secret" = spec.postgresSecretName
            "backstage.appConfig.backend.database.connection.password.key" = spec.postgresSecretKey
    }

    _techdocs_values: {str:str} = {
        "backstage.appConfig.techdocs.builder" = spec.techdocsBuilder
        "backstage.appConfig.techdocs.generator.runIn" = spec.techdocsGeneratorType
    }

    _resource_values: {str:str} = {
        if spec.cpuRequest:
            "backstage.resources.requests.cpu" = spec.cpuRequest
        if spec.memoryRequest:
            "backstage.resources.requests.memory" = spec.memoryRequest
        if spec.cpuLimit:
            "backstage.resources.limits.cpu" = spec.cpuLimit
        if spec.memoryLimit:
            "backstage.resources.limits.memory" = spec.memoryLimit
    }

    _ingress_values: {str:str} = {
        if spec.host:
            "ingress.enabled" = "true"
            "ingress.host" = spec.host
    }

    _all_values: {str:str} = _base_values \
        | _postgres_values \
        | _techdocs_values \
        | _resource_values \
        | _ingress_values \
        | (spec.extraValues or {})

    _helm_spec = th.ThirdPartyHelmSpec {
        name = spec.name
        namespace = spec.namespace
        chart = "backstage/backstage"
        version = spec.chartVersion
        repository = "https://backstage.github.io/charts"
        values = _all_values
    }

    th.build_thirdparty_helm(_helm_spec)
}

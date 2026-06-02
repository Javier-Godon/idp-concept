"""
Helmfile integration test fixture.

Renders a simple web app + database stack to Helmfile format and validates:
- Helmfile structure and syntax
- Generated Helm charts can be templated without errors
- Dependency ordering (needs) is resolvable
"""

import framework.tests.acceptance.cases._helpers as h

_namespace = h.create_namespace("helmfile-test", h.default_configurations())

# Simple webapp module
_webapp_config = {
    port = 8080
    replicas = 1
    env = [
        { name = "LOG_LEVEL", value = "info" }
    ]
}

_webapp = h.render_component(
    "helmfile-test",
    _namespace,
    templates.webapp.v1_0_0.webapp.WebAppModule {
        name = "test-app"
        namespace = _namespace.instance.name
        image = "nginx:1.27.3"
        version = "1.0.0"
        port = _webapp_config.port
        replicas = _webapp_config.replicas
        env = _webapp_config.env
    },
    "1.0.0"
)

# Simple database module
_db_config = {
    port = 5432
    storageSize = "5Gi"
}

_db = h.render_accessory(
    "helmfile-test",
    _namespace,
    templates.database.v1_0_0.database.SingleDatabaseModule {
        name = "test-db"
        namespace = _namespace.instance.name
        image = "postgres:16-alpine"
        version = "16"
        port = _db_config.port
        dataPath = "/var/lib/postgresql/data"
        storageSize = _db_config.storageSize
        storageClassName = "standard"
        env = [
            { name = "POSTGRES_DB", value = "testdb" }
        ]
    },
    "1.0.0"
)

# Render the stack to Helmfile
manifests.yaml_stream(h.render_stack(
    [_namespace],
    [_webapp],
    [_db]
))


"""
Acceptance fixture: WebAppModule + PostgreSQLClusterModule co-deployed in one stack.

Models the most common web application + relational database IDP stack: a webapp
Deployment wired to a CloudNativePG PostgreSQL Cluster CR in the same namespace.

The webapp uses the pause image and sets DB_HOST to the CNPG read/write service
name pattern (<clusterName>-rw). Both modules are rendered through a single
RenderStack via render_stack, exercising the full multi-module IDP stack path.

Dry-run-only in acceptance_kind.sh. Real apply requires CloudNativePG operator
and a working StorageClass (see docs/ACCEPTANCE_DEPENDENCIES.md).

Covers:
- Application + relational database IDP stack via render_stack
- WebApp Component + PostgreSQL Accessory in the same namespace
- CNPG Cluster CR shape alongside Deployment resources in one manifest
- Cross-module env wiring: DB_HOST points at CNPG read/write service
"""

import ._helpers as h
import templates.webapp.v1_0_0.webapp as webapp
import templates.postgresql.v1_0_0.postgresql as pg

_namespace = "idp-acceptance-webapp-postgresql-stack"

_app = webapp.WebAppModule {
    name = "acceptance-webapp-pg"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\ndb.host: acceptance-postgresql-stack-rw\ndb.port: 5432\ndb.name: appdb\n"}
    env = [
        {name = "DB_HOST", value = "acceptance-postgresql-stack-rw"}
        {name = "DB_PORT", value = "5432"}
        {name = "DB_NAME", value = "appdb"}
    ]
}.instance

_pg = pg.PostgreSQLClusterModule {
    name = "acceptance-postgresql-stack"
    namespace = _namespace
    configurations = {}
    asset = {version = "16.4"}
    dependsOn = []
    clusterName = "acceptance-postgresql-stack"
    instances = 1
    storageSize = "1Gi"
    databaseName = "appdb"
    databaseOwner = "appuser"
}.instance

h.render_stack([_namespace], [_app], [_pg])


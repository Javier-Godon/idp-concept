"""
Acceptance scenario: KeycloakModule configured for a PostgreSQLClusterModule.

This validates the IDP render path for the common production dependency:
Keycloak can render without a database, but persistent Keycloak deployments need
a PostgreSQL endpoint plus a username/password Secret referenced by the
Keycloak CR. The real runtime also requires CloudNativePG and Keycloak operators.
"""

import ._helpers as h
import templates.keycloak as kc
import templates.postgresql as pg

_namespace = "idp-acceptance-keycloak-postgresql"

_postgresql = pg.PostgreSQLClusterModule {
    name = "acceptance-keycloak-postgresql"
    namespace = _namespace
    configurations = {}
    asset = {version = "16.4"}
    dependsOn = []
    clusterName = "acceptance-keycloak-postgresql"
    instances = 1
    storageSize = "1Gi"
    databaseName = "keycloak"
    databaseOwner = "keycloak"
}.instance

_keycloak = kc.KeycloakModule {
    name = "acceptance-keycloak"
    namespace = _namespace
    configurations = {}
    asset = {version = "26.0.0"}
    dependsOn = [_postgresql]
    keycloakName = "acceptance-keycloak"
    instances = 1
    hostname = "keycloak.acceptance.example"
    httpEnabled = True
    databaseVendor = "postgres"
    databaseHost = "acceptance-keycloak-postgresql-rw"
    databasePort = 5432
    databaseName = "keycloak"
    databaseSecretName = "acceptance-keycloak-postgresql-app"
}.instance

h.render_stack([_namespace], [], [_postgresql, _keycloak])


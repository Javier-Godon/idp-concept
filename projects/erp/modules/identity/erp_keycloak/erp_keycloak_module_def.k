"""
erp keycloak module — Keycloak Operator, single instance for development.
The crossplane output renders it as an XKeycloak reconciled by
crossplane_v2/managed_resources/keycloak; the realm data lives in the erp postgres database.
Credentials are never rendered: the database Secret is referenced by name only and must exist in
the Keycloak operator namespace.
"""
import framework.templates.keycloak.v1_0_0.keycloak as keycloak

schema ErpKeycloakModule(keycloak.KeycloakModule):
    keycloakName = name
    footprint = configurations.keycloakFootprint
    hostname = configurations.keycloakHostname
    path = configurations.keycloakPath
    databaseVendor = "postgres"
    databaseHost = "${configurations.postgresClusterName}-rw.${configurations.postgresNamespace}.svc.cluster.local"
    databaseName = configurations.postgresDatabase
    databaseSchema = configurations.keycloakDbSchema
    databaseSecretName = configurations.keycloakDbSecret

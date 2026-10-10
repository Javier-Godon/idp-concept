"""
erp postgres module — CloudNativePG PostgreSQL.
The crossplane output renders it as an XPostgresInstance reconciled by
crossplane_v2/managed_resources/postgres; sizing follows the configured footprint.
Credentials are never rendered: the superuser Secret is referenced by name only.
"""
import framework.templates.postgresql.v1_0_0.postgresql as postgresql

schema ErpPostgresModule(postgresql.PostgreSQLClusterModule):
    clusterName = name
    footprint = configurations.postgresFootprint
    storageClass = configurations.storageClassName
    databaseName = configurations.postgresDatabase
    superuserSecretName = configurations.postgresSuperuserSecret
    nodePort = configurations.postgresNodePort
    imageName = "ghcr.io/cloudnative-pg/postgresql:${asset.version}"

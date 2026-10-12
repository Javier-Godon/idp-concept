"""
erp project-specific configuration schema.
Extends BaseConfigurations with project-specific fields.
"""

import framework.models.configurations as base

schema ErpConfigurations(base.BaseConfigurations):
    cacheNamespace?: str
    valkeyAdminHostname?: str
    valkeyAdminPath?: str
    valkeyAdminBasicAuthSecret?: str
    postgresNamespace?: str
    postgresFootprint?: "local" | "development" | "staging" | "production"
    postgresDatabase?: str
    postgresSuperuserSecret?: str
    postgresNodePort?: int
    postgresClusterName?: str
    keycloakNamespace?: str
    keycloakFootprint?: "local" | "development" | "staging" | "production"
    keycloakHostname?: str
    keycloakPath?: str
    keycloakDbSchema?: str
    keycloakDbSecret?: str
    footprint?: "local" | "development" | "staging" | "production"
    # erp-backend (Spring Boot API, Tier-1 GitOps YAML via the dev_apps pre-release)
    erpBackendImage?: str
    erpBackendVersion?: str
    # Context path the application serves under, and the public prefix APISIX publishes it at.
    erpBackendPath?: str
    erpApiPath?: str
    erpBackendPullSecret?: str
    erpBackendDbSecret?: str
    erpBackendKeycloakSecret?: str
    erpBackendKeycloakRealm?: str
    # APISIX API gateway (curated XAPIGateway); the Admin API keys Secret is created out of band in apisixNamespace.
    apisixNamespace?: str
    apisixName?: str
    apisixFootprint?: "local" | "development" | "staging" | "production"
    apisixHostname?: str
    apisixAdminKeySecret?: str
    apisixAdminAllowCidrs?: [str]
    apisixEtcdStorageClass?: str

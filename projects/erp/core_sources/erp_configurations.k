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
    erpBackendHostname?: str
    erpBackendPath?: str
    erpBackendPullSecret?: str
    erpBackendDbSecret?: str
    erpBackendKeycloakSecret?: str
    erpBackendKeycloakRealm?: str

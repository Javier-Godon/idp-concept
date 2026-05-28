"""
Acceptance fixture: KeycloakModule through the IDP render path.
"""

import ._helpers as h
import templates.keycloak.v1_0_0.keycloak as kc

_module = kc.KeycloakModule {
    name = "acceptance-keycloak"
    namespace = "idp-acceptance-keycloak"
    configurations = {}
    asset = {version = "26.0.0"}
    dependsOn = []
    keycloakName = "acceptance-keycloak"
    instances = 1
    hostname = "keycloak.acceptance.example"
    httpEnabled = True
    realmImport = kc.KeycloakRealmImportSpec {
        name = "acceptance-keycloak-realm"
        namespace = "idp-acceptance-keycloak"
        keycloakName = "acceptance-keycloak"
        realmName = "acceptance"
    }
}.instance

h.render_accessory("idp-acceptance-keycloak", _module)


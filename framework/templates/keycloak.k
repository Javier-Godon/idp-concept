"""Backward-compatible Keycloak template wrapper.

The implementation lives in `templates.keycloak.main`. Keep this root module thin so
existing imports such as `import templates.keycloak as keycloak` continue to work
without duplicating template implementation code.
"""

import templates.keycloak.main as keycloak_compat

KeycloakSpec = keycloak_compat.KeycloakSpec
KeycloakRealmImportSpec = keycloak_compat.KeycloakRealmImportSpec
build_keycloak = keycloak_compat.build_keycloak
build_keycloak_realm_import = keycloak_compat.build_keycloak_realm_import
KeycloakModule = keycloak_compat.KeycloakModule

"""
Keycloak Template Tests.

Tests the build_keycloak and build_keycloak_realm_import lambdas
for the Keycloak Operator (k8s.keycloak.org/v2alpha1).
"""
import templates.keycloak as kc
import runtime

# === Test: build_keycloak generates correct Keycloak CRD ===
test_build_keycloak_basic = lambda {
    _result = kc.build_keycloak(kc.KeycloakSpec {
        name = "my-kc"
        namespace = "auth"
        instances = 1
        hostname = "keycloak.example.com"
    })
    assert _result.apiVersion == "k8s.keycloak.org/v2alpha1"
    assert _result.kind == "Keycloak"
    assert _result.metadata.name == "my-kc"
    assert _result.metadata.namespace == "auth"
    assert _result.spec.instances == 1
    assert _result.spec.hostname.hostname == "keycloak.example.com"
}

# === Test: Keycloak with database config ===
test_build_keycloak_with_db = lambda {
    _result = kc.build_keycloak(kc.KeycloakSpec {
        name = "my-kc"
        namespace = "auth"
        instances = 2
        hostname = "keycloak.example.com"
        databaseVendor = "postgres"
        databaseHost = "pg-cluster-rw"
        databasePort = 5432
        databaseName = "keycloak"
        databaseSecretName = "kc-db-secret"
    })
    assert _result.spec.db.vendor == "postgres"
    assert _result.spec.db.host == "pg-cluster-rw"
    assert _result.spec.db.port == 5432
    assert _result.spec.db.database == "keycloak"
    assert _result.spec.db.usernameSecret.name == "kc-db-secret"
    assert _result.spec.db.usernameSecret.key == "username"
    assert _result.spec.db.passwordSecret.name == "kc-db-secret"
    assert _result.spec.db.passwordSecret.key == "password"
}

# === Test: Keycloak with HTTP config ===
test_build_keycloak_with_http = lambda {
    _result = kc.build_keycloak(kc.KeycloakSpec {
        name = "my-kc"
        namespace = "auth"
        instances = 1
        hostname = "keycloak.example.com"
        httpEnabled = True
        tlsSecretName = "kc-tls"
    })
    assert _result.spec.http.httpEnabled == True
    assert _result.spec.http.tlsSecret == "kc-tls"
}

# === Test: Keycloak defaults — no db, no http override ===
test_build_keycloak_defaults = lambda {
    _result = kc.build_keycloak(kc.KeycloakSpec {
        name = "my-kc"
        namespace = "auth"
        instances = 1
        hostname = "keycloak.example.com"
    })
    assert _result.spec.instances == 1
}

# === Test: build_keycloak_realm_import generates CRD ===
test_build_keycloak_realm_import = lambda {
    _result = kc.build_keycloak_realm_import(kc.KeycloakRealmImportSpec {
        name = "my-realm-import"
        namespace = "auth"
        keycloakName = "my-kc"
        realmName = "my-realm"
    })
    assert _result.apiVersion == "k8s.keycloak.org/v2alpha1"
    assert _result.kind == "KeycloakRealmImport"
    assert _result.metadata.name == "my-realm-import"
    assert _result.spec.keycloakCRName == "my-kc"
    assert _result.spec.realm.realm == "my-realm"
    assert _result.spec.realm.enabled == True
}

# === Test: Validation — instances must be >= 1 ===
test_keycloak_rejects_zero_instances = lambda {
    _err = runtime.catch(lambda {
        kc.KeycloakSpec {
            name = "bad"
            namespace = "auth"
            instances = 0
            hostname = "keycloak.example.com"
        }
    })
    assert _err, "Expected validation error for instances=0"
}

# === Test: Validation — hostname must not be empty ===
test_keycloak_rejects_empty_hostname = lambda {
    _err = runtime.catch(lambda {
        kc.KeycloakSpec {
            name = "bad"
            namespace = "auth"
            instances = 1
            hostname = ""
        }
    })
    assert _err, "Expected validation error for empty hostname"
}

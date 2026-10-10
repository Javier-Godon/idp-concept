"""
Keycloak Template Tests.

Tests the build_keycloak and build_keycloak_realm_import lambdas
for the Keycloak Operator (k8s.keycloak.org/v2alpha1).
"""
import templates.keycloak.v1_0_0.keycloak as kc
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

_dev = kc.KeycloakModule {
    name = "iam"
    namespace = "keycloak"
    configurations = {}
    asset = {version = "26.4.0"}
    dependsOn = []
    keycloakName = "iam"
    hostname = "example.com"
    path = "/iam"
    footprint = "development"
    databaseVendor = "postgres"
    databaseHost = "pg-rw"
    databaseName = "keycloak"
    databaseSchema = "keycloak"
    databaseSecretName = "kc-db"
}.instance

_root_no_route = kc.KeycloakModule {
    name = "iam"
    namespace = "keycloak"
    configurations = {}
    asset = {version = "26.4.0"}
    dependsOn = []
    keycloakName = "iam"
    hostname = "example.com"
    exposeOnGateway = False
}.instance

_prod = kc.KeycloakModule {
    name = "iam"
    namespace = "keycloak"
    configurations = {}
    asset = {version = "26.4.0"}
    dependsOn = []
    keycloakName = "iam"
    hostname = "example.com"
}.instance

_prod_explicit = kc.KeycloakModule {
    name = "iam"
    namespace = "keycloak"
    configurations = {}
    asset = {version = "26.4.0"}
    dependsOn = []
    keycloakName = "iam"
    hostname = "example.com"
    instances = 2
}.instance

# === Test: served under a path prefix behind the gateway ===
test_keycloak_module_path_prefix = lambda {
    _kc = _dev.manifests[0]
    assert _kc.spec.hostname.hostname == "https://example.com/iam"
    assert _kc.spec.proxy.headers == "xforwarded"
    assert _kc.spec.additionalOptions == [{name = "http-relative-path", value = "/iam"}]
    assert _kc.spec.db.schema == "keycloak"
    assert _kc.spec.instances == 1
}

# === Test: HTTPRoute forwards the path unchanged to the operator Service ===
test_keycloak_module_http_route = lambda {
    _route = _dev.manifests[1]
    assert _route.kind == "HTTPRoute"
    assert _route.spec.hostnames == ["example.com"]
    assert _route.spec.rules[0].matches[0].path.value == "/iam"
    assert _route.spec.rules[0].backendRefs[0].name == "iam-service"
    assert _route.spec.rules[0].backendRefs[0].port == 8080
    assert not _route.spec.rules[0].filters
}

# === Test: root path needs no relative-path option; route can be disabled ===
test_keycloak_module_root_path_without_route = lambda {
    assert len(_root_no_route.manifests) == 1
    assert not _root_no_route.manifests[0].spec.additionalOptions
    assert _root_no_route.manifests[0].spec.hostname.hostname == "https://example.com/"
}

# === Test: crossplane output is the curated XKeycloak ===
test_keycloak_module_crossplane_spec = lambda {
    assert _dev.component == "keycloak"
    assert _dev.crossplaneSpec == {
        hostname = "example.com"
        instances = 1
        db = {host = "pg-rw", database = "keycloak", schema = "keycloak", vendor = "postgres", secretRef.name = "kc-db"}
        route = {path = "/iam", listener = "https"}
        environment = "development"
    }
}

# === Test: footprint sizes instances ===
test_keycloak_module_footprint_instances = lambda {
    assert _prod.crossplaneSpec.instances == 3
    assert _prod_explicit.crossplaneSpec.instances == 2
}

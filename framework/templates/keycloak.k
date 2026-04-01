"""
Keycloak Module Template — Keycloak Operator pattern.
Generates: Keycloak CRD + optional KeycloakRealmImport CRD.

CRD API: k8s.keycloak.org/v2alpha1
Operator: Keycloak Operator (https://www.keycloak.org/operator/installation)

Usage:
    import framework.templates.keycloak as kc

    schema MyKeycloak(kc.KeycloakModule):
        keycloakName = "my-kc"
        instances = 2
        hostname = "keycloak.example.com"
        databaseVendor = "postgres"
        databaseHost = "pg-cluster-rw"
        databaseSecretName = "kc-db-secret"
"""
import models.modules.accessory as accessory
import builders.leader as leader

_API_VERSION = "k8s.keycloak.org/v2alpha1"

schema KeycloakSpec:
    """Specification for a Keycloak resource."""
    name: str
    namespace: str
    instances: int = 1
    hostname: str
    httpEnabled?: bool
    tlsSecretName?: str
    image?: str
    databaseVendor?: str
    databaseHost?: str
    databasePort?: int
    databaseName?: str
    databaseSecretName?: str

    check:
        instances >= 1, "instances must be >= 1"
        len(hostname) > 0, "hostname must not be empty"

schema KeycloakRealmImportSpec:
    """Specification for a KeycloakRealmImport resource."""
    name: str
    namespace: str
    keycloakName: str
    realmName: str
    realmEnabled?: bool = True

build_keycloak = lambda spec: KeycloakSpec -> any {
    _db = {if spec.databaseVendor: db = {
        vendor = spec.databaseVendor
        if spec.databaseHost: host = spec.databaseHost
        if spec.databasePort: port = spec.databasePort
        if spec.databaseName: database = spec.databaseName
        if spec.databaseSecretName: usernameSecret = {
            name = spec.databaseSecretName
            key = "username"
        }
        if spec.databaseSecretName: passwordSecret = {
            name = spec.databaseSecretName
            key = "password"
        }
    }}
    _http = {if spec.httpEnabled != None or spec.tlsSecretName: http = {
        if spec.httpEnabled != None: httpEnabled = spec.httpEnabled
        if spec.tlsSecretName: tlsSecret = spec.tlsSecretName
    }}
    _image = {if spec.image: image = spec.image}
    {
        apiVersion = _API_VERSION
        kind = "Keycloak"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            instances = spec.instances
            hostname = {hostname = spec.hostname}
        } | _db | _http | _image
    }
}

build_keycloak_realm_import = lambda spec: KeycloakRealmImportSpec -> any {
    {
        apiVersion = _API_VERSION
        kind = "KeycloakRealmImport"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            keycloakCRName = spec.keycloakName
            realm = {
                realm = spec.realmName
                enabled = spec.realmEnabled
            }
        }
    }
}

schema KeycloakModule(accessory.Accessory):
    """High-level template for Keycloak instances via the Keycloak Operator.

    Extends Accessory with kind="CRD" and generates Keycloak CRD +
    optional KeycloakRealmImport CRD manifests.
    """
    kind = "CRD"

    # User-configurable
    keycloakName: str
    instances?: int = 1
    hostname: str
    httpEnabled?: bool
    tlsSecretName?: str
    image?: str
    databaseVendor?: str
    databaseHost?: str
    databasePort?: int
    databaseName?: str
    databaseSecretName?: str
    realmImport?: KeycloakRealmImportSpec

    # Auto-computed
    leaders = [leader.build_accessory_leader(keycloakName, namespace, "Keycloak", _API_VERSION)]

    _keycloak_manifest = build_keycloak(KeycloakSpec {
        name = keycloakName
        namespace = namespace
        instances = instances
        hostname = hostname
        httpEnabled = httpEnabled
        tlsSecretName = tlsSecretName
        image = image
        databaseVendor = databaseVendor
        databaseHost = databaseHost
        databasePort = databasePort
        databaseName = databaseName
        databaseSecretName = databaseSecretName
    })

    _realm_manifests = [build_keycloak_realm_import(realmImport)] if realmImport else []

    manifests = [_keycloak_manifest] + _realm_manifests

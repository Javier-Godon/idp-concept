"""
Keycloak Module Template — Keycloak Operator pattern.
Generates: Keycloak CRD + HTTPRoute on the platform gateway + optional KeycloakRealmImport CRD.
The crossplane output emits an XKeycloak XR instead (crossplane_v2/managed_resources/keycloak).

CRD API: k8s.keycloak.org/v2alpha1
Operator: Keycloak Operator (https://www.keycloak.org/operator/installation)

Usage:
    import framework.templates.keycloak.v1_0_0.keycloak as kc

    schema MyKeycloak(kc.KeycloakModule):
        keycloakName = "my-kc"
        instances = 2
        hostname = "example.com"
        path = "/iam"
        databaseVendor = "postgres"
        databaseHost = "pg-cluster-rw"
        databaseSecretName = "kc-db-secret"

`hostname` is the bare public host name; Keycloak is served at `<listener>://<hostname><path>`
(TLS terminates at the gateway, so the Keycloak Service speaks plain HTTP behind it).

The Keycloak operator watches only the namespace it runs in: `namespace` must be the operator's
namespace, and the database Secret (`databaseSecretName`) must exist there.
"""
import models.modules.accessory as accessory
import builders.leader as leader
import builders.route as route_builder
import templates.footprints.v1_0_0.footprint as fp

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
    databaseSchema?: str
    databaseSecretName?: str
    # Path prefix Keycloak is served under (http-relative-path); "/" serves at the root.
    relativePath?: str = "/"
    proxyHeaders?: "xforwarded" | "forwarded" = "xforwarded"

    check:
        instances >= 1, "instances must be >= 1"
        len(hostname) > 0, "hostname must not be empty"
        relativePath.startswith("/"), "relativePath must start with '/'"

schema KeycloakRealmImportSpec:
    """Specification for a KeycloakRealmImport resource."""
    name: str
    namespace: str
    keycloakName: str
    realmName: str
    realmEnabled?: bool = True

public_url = lambda hostname: str, listener: str, path: str -> str {
    """Public base URL Keycloak is reachable at through the gateway (Keycloak `hostname` option)."""
    "${listener}://${hostname}${path}"
}

build_keycloak_xr_spec = lambda spec: KeycloakSpec, footprint: str, listener: str = "https", owner: str = "" -> {str:} {
    """XKeycloak spec (crossplane_v2/managed_resources/keycloak) for the crossplane output.
    `spec.hostname` is the bare public host name; the XR derives the Keycloak hostname URL and the HTTPRoute."""
    {
        hostname = spec.hostname
        instances = spec.instances
        if spec.databaseHost:
            db = {
                host = spec.databaseHost
                if spec.databaseName:
                    database = spec.databaseName
                if spec.databaseSchema:
                    schema = spec.databaseSchema
                if spec.databaseVendor:
                    vendor = spec.databaseVendor
                if spec.databaseSecretName:
                    secretRef.name = spec.databaseSecretName
            }
        route = {
            path = spec.relativePath
            listener = listener
        }
        environment = footprint
        if owner:
            owner = owner
    }
}

build_keycloak = lambda spec: KeycloakSpec -> any {
    _db = {if spec.databaseVendor: db = {
        vendor = spec.databaseVendor
        if spec.databaseHost: host = spec.databaseHost
        if spec.databasePort: port = spec.databasePort
        if spec.databaseName: database = spec.databaseName
        if spec.databaseSchema: schema = spec.databaseSchema
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
    _relative_path = {if spec.relativePath != "/": additionalOptions = [{
        name = "http-relative-path"
        value = spec.relativePath
    }]}
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
            proxy.headers = spec.proxyHeaders
        } | _db | _http | _image | _relative_path
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

    Extends Accessory with kind="CRD" and generates the Keycloak CRD, an HTTPRoute on the platform
    gateway (disable with `exposeOnGateway = False`) and an optional KeycloakRealmImport CRD.
    The crossplane output emits an XKeycloak XR instead.
    """
    kind = "CRD"
    component = "keycloak"

    # User-configurable
    keycloakName: str
    footprint?: str = "production"
    instances?: int
    # Bare public host name (no scheme, path or port).
    hostname: str
    # Path prefix Keycloak is served under, e.g. "/iam".
    path?: str = "/"
    listener?: "https" | "http" = "https"
    exposeOnGateway?: bool = True
    httpEnabled?: bool
    tlsSecretName?: str
    image?: str
    databaseVendor?: str
    databaseHost?: str
    databasePort?: int
    databaseName?: str
    databaseSchema?: str
    databaseSecretName?: str
    realmImport?: KeycloakRealmImportSpec

    # Auto-computed
    leaders = [leader.build_accessory_leader(keycloakName, namespace, "Keycloak", _API_VERSION)]

    _instances: int = instances if instances is not Undefined else fp.replicas(footprint, 1, 1, 2, 3)

    _keycloak_spec = KeycloakSpec {
        name = keycloakName
        namespace = namespace
        instances = _instances
        hostname = hostname
        httpEnabled = httpEnabled
        tlsSecretName = tlsSecretName
        image = image
        databaseVendor = databaseVendor
        databaseHost = databaseHost
        databasePort = databasePort
        databaseName = databaseName
        databaseSchema = databaseSchema
        databaseSecretName = databaseSecretName
        relativePath = path
    }

    _keycloak_manifest = build_keycloak(KeycloakSpec {
        **_keycloak_spec
        hostname = public_url(hostname, listener, path)
    })

    # keycloak-operator names the HTTP Service <keycloak>-service.
    _route_manifests = [route_builder.build_http_route(route_builder.HTTPRouteSpec {
        name = keycloakName
        namespace = namespace
        serviceName = "${keycloakName}-service"
        servicePort = 8080
        route = route_builder.RouteSpec {
            hostnames = [hostname]
            path = path
            listener = listener
        }
    })] if exposeOnGateway else []

    _realm_manifests = [build_keycloak_realm_import(realmImport)] if realmImport else []

    crossplaneSpec = build_keycloak_xr_spec(_keycloak_spec, footprint, listener)

    manifests = [_keycloak_manifest] + _route_manifests + _realm_manifests

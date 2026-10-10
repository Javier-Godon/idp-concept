"""
Valkey Admin Template — web UI (https://github.com/valkey-io/valkey-admin) for Valkey instances.

Renders a Deployment + Service and, when `hostname` is set, an HTTPRoute on the platform gateway
that serves the UI under a sub-path (default `/valkey-admin`) of a shared hostname.

Valkey Admin Web mode has NO built-in authentication and lets any user open connections to
arbitrary hosts, so never expose it without an authenticating layer. `basicAuthSecretName`
attaches an Envoy Gateway SecurityPolicy (HTTP basic auth) to the route; staging/production
footprints require it whenever the UI is published. The Secret (key `.htpasswd`, SHA hashes)
is referenced by name only and must be created out of band.

Sub-path hosting works because the frontend uses relative asset URLs, a HashRouter and derives
its WebSocket URL from `location.pathname`; the route strips the prefix and redirects
`<path>` to `<path>/`.

Usage:
    import templates.valkey.v1_0_0.valkey_admin as valkey_admin

    _resources = valkey_admin.build_valkey_admin_resources(valkey_admin.ValkeyAdminSpec {
        name = "cache-admin"
        namespace = "data"
        valkeyHost = "cache-primary.data.svc.cluster.local"
        hostname = "example.com"
        basicAuthSecretName = "valkey-admin-basic-auth"
    })
"""

import builders.deployment as deploy
import builders.service as svc
import builders.route as route_builder
import builders.leader as leader
import models.modules.component as component
import models.modules.common as common

_SECURITY_POLICY_API = "gateway.envoyproxy.io/v1alpha1"

schema ValkeyAdminResources:
    # Web mode runs one metrics collector per primary (~150MB each) next to the UI (~1GB).
    cpuRequest?: str = "100m"
    cpuLimit?: str = "1"
    memoryRequest?: str = "512Mi"
    memoryLimit?: str = "1536Mi"

schema ValkeyAdminOptions:
    """Per-instance options; the owning template supplies name, namespace and Valkey endpoint."""
    image?: str = "valkey/valkey-admin"
    version?: str = "1.2.0"
    port?: int = 8080
    serviceType?: str = "ClusterIP"
    valkeyPort?: int = 6379
    # Optional Secret holding the Valkey password; preconfigures the connection (VALKEY_PASSWORD).
    passwordSecretName?: str
    passwordSecretKey?: str = "password"
    # Public exposure on the platform gateway. Bare host name (no scheme, path or port); unset = cluster-internal only.
    hostname?: str
    path?: str = "/valkey-admin"
    listener?: "https" | "http" = "https"
    gatewayName?: str = route_builder.DEFAULT_GATEWAY_NAME
    gatewayNamespace?: str = route_builder.DEFAULT_GATEWAY_NAMESPACE
    # Secret with an `.htpasswd` key enforced by an Envoy Gateway SecurityPolicy on the route.
    basicAuthSecretName?: str
    resources?: ValkeyAdminResources = ValkeyAdminResources {}

    check:
        len(version) > 0 and "latest" not in version, "Valkey Admin image version must be pinned and not latest"
        1 <= port <= 65535, "Valkey Admin port must be between 1 and 65535"
        1 <= valkeyPort <= 65535, "valkeyPort must be between 1 and 65535"
        path.startswith("/") and not path.endswith("/"), "Valkey Admin path must start with '/' and must not end with '/' (e.g. /valkey-admin)"
        len(hostname) > 0 if hostname is not Undefined, "Valkey Admin hostname must not be empty"
        serviceType in ["ClusterIP", "NodePort", "LoadBalancer"], "serviceType must be ClusterIP, NodePort, or LoadBalancer"

schema ValkeyAdminSpec(ValkeyAdminOptions):
    name: str
    namespace: str
    # Service host of the Valkey instance to preconfigure.
    valkeyHost: str
    footprint?: str = "development"

    check:
        len(name) > 0, "Valkey Admin name must not be empty"
        len(namespace) > 0, "Valkey Admin namespace must not be empty"
        len(valkeyHost) > 0, "valkeyHost must not be empty"
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        basicAuthSecretName is not Undefined if hostname is not Undefined and footprint in ["staging", "production"], "staging/production Valkey Admin published on a hostname requires basicAuthSecretName (the UI has no built-in authentication)"

admin_url = lambda hostname: str, path: str, listener: str = "https" -> str {
    """Public URL of the UI (with the trailing slash the relative asset URLs need)."""
    "${listener}://${hostname}${path}/"
}

build_valkey_admin_xr_spec = lambda options: ValkeyAdminOptions -> {str:} {
    """`adminUi` block of XValkeyInstance (crossplane_v2/managed_resources/valkey).
    The composition derives name, namespace and Valkey endpoint from the XR."""
    {
        image = "${options.image}:${options.version}"
        if options.hostname:
            hostname = options.hostname
            path = options.path
            listener = options.listener
            gatewayName = options.gatewayName
            gatewayNamespace = options.gatewayNamespace
        if options.basicAuthSecretName:
            basicAuthSecretName = options.basicAuthSecretName
        if options.passwordSecretName:
            passwordSecretName = options.passwordSecretName
            passwordSecretKey = options.passwordSecretKey
    }
}

_build_env = lambda spec: ValkeyAdminSpec -> [any] {
    [
        common.EnvVar {name = "DEPLOYMENT_MODE", value = "Web"}
        common.EnvVar {name = "PORT", value = str(spec.port)}
        common.EnvVar {name = "VALKEY_HOST", value = spec.valkeyHost}
        common.EnvVar {name = "VALKEY_PORT", value = str(spec.valkeyPort)}
    ] + ([common.EnvVar {
        name = "VALKEY_PASSWORD"
        valueFrom = common.EnvVarSource {secretKeyRef = common.KeySelector {name = spec.passwordSecretName, key = spec.passwordSecretKey}}
    }] if spec.passwordSecretName else []) + ([common.EnvVar {
        # Web mode only accepts same-origin WebSocket handshakes; name the public origin explicitly.
        name = "VALKEY_ADMIN_ALLOWED_WS_ORIGINS"
        value = "${spec.listener}://${spec.hostname}"
    }] if spec.hostname else [])
}

build_valkey_admin_resources = lambda spec: ValkeyAdminSpec -> [any] {
    _deployment = deploy.build_deployment(deploy.DeploymentSpec {
        name = spec.name
        namespace = spec.namespace
        image = spec.image
        version = spec.version
        # Metrics collectors and sessions live in the process, so the UI is not horizontally scalable.
        replicas = 1
        port = spec.port
        env = _build_env(spec)
        resources = deploy.ResourceSpec {
            cpuRequest = spec.resources.cpuRequest
            cpuLimit = spec.resources.cpuLimit
            memoryRequest = spec.resources.memoryRequest
            memoryLimit = spec.resources.memoryLimit
        }
        livenessProbe = deploy.ProbeSpec {probeType = "http", path = "/", port = spec.port, initialDelaySeconds = 30, periodSeconds = 10}
        readinessProbe = deploy.ProbeSpec {probeType = "http", path = "/", port = spec.port, initialDelaySeconds = 10, periodSeconds = 5}
        # The image runs as the non-root `node` user (uid 1000).
        podSecurityContext = {
            runAsNonRoot = True
            runAsUser = 1000
            runAsGroup = 1000
            seccompProfile = {$type = "RuntimeDefault"}
        }
        containerSecurityContext = {
            allowPrivilegeEscalation = False
            capabilities = {drop = ["ALL"]}
        }
    })
    _service = svc.build_service(svc.ServiceSpec {
        name = spec.name
        namespace = spec.namespace
        port = spec.port
        targetPort = spec.port
        serviceType = spec.serviceType
        portName = "http"
    })
    _route = [route_builder.build_http_route(route_builder.HTTPRouteSpec {
        name = spec.name
        namespace = spec.namespace
        serviceName = spec.name
        servicePort = spec.port
        route = route_builder.RouteSpec {
            hostnames = [spec.hostname]
            path = spec.path
            rewritePrefix = "/"
            trailingSlashRedirect = True
            listener = spec.listener
            gatewayName = spec.gatewayName
            gatewayNamespace = spec.gatewayNamespace
        }
    })] if spec.hostname else []
    _policy = [{
        apiVersion = _SECURITY_POLICY_API
        kind = "SecurityPolicy"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            targetRefs = [{
                group = "gateway.networking.k8s.io"
                kind = "HTTPRoute"
                name = spec.name
            }]
            basicAuth.users.name = spec.basicAuthSecretName
        }
    }] if spec.hostname and spec.basicAuthSecretName else []
    [_deployment, _service] + _route + _policy
}

schema ValkeyAdminModule(component.Component):
    """Standalone Valkey Admin UI for an existing Valkey instance (any template or external service)."""
    kind = "INFRASTRUCTURE"
    valkeyHost: str
    options?: ValkeyAdminOptions = ValkeyAdminOptions {}
    footprint?: str = "development"
    leaders = [leader.build_component_leader(name, namespace)]
    manifests = build_valkey_admin_resources(ValkeyAdminSpec {
        **options
        name = name
        namespace = namespace
        valkeyHost = valkeyHost
        footprint = footprint
        image = asset.image if asset.image else options.image
        version = asset.version
    })

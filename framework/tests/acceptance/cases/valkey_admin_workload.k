"""
Acceptance fixture: Valkey Admin UI served under a sub-path of a shared hostname through the IDP render path.
Dry-run only: it needs the Gateway API and Envoy Gateway SecurityPolicy CRDs (stubbed by the dry-run runner).
"""
import ._helpers as h
import templates.valkey.v1_0_0.valkey_admin as valkey_admin

_namespace = "idp-acceptance-valkey-admin"
_module = valkey_admin.ValkeyAdminModule {
    name = "acceptance-valkey-admin"
    namespace = _namespace
    configurations = {}
    asset = {version = "1.2.0"}
    dependsOn = []
    valkeyHost = "acceptance-valkey.${_namespace}.svc.cluster.local"
    footprint = "local"
    options = valkey_admin.ValkeyAdminOptions {
        hostname = "acceptance.example.com"
        basicAuthSecretName = "acceptance-valkey-admin-basic-auth"
    }
}.instance
h.render_component(_namespace, _module)

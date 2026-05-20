"""
Runtime rollout fixture: WebAppModule with a ServiceAccount generated via imagePullSecretName.

When imagePullSecretName is set on WebAppModule the template generates a
ServiceAccount (with an imagePullSecrets reference) and wires it to the
Deployment via serviceAccountName. This fixture keeps that ServiceAccount +
Deployment shape and patches out the imagePullSecrets from the SA and from the
pod spec so the rollout can proceed with the pause image in kind without a real
registry secret.

Covers: ServiceAccount generation, serviceAccountName wiring, imagePullSecrets
patching pattern for acceptance environments.
"""

import ._helpers as h
import templates.webapp as webapp

_namespace = "idp-acceptance-webapp-sa-rollout"

_base = webapp.WebAppModule {
    name = "acceptance-webapp-sa"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    imagePullSecretName = "acceptance-registry-secret"
}.instance

# Patch: remove pull-secret references so the pause image rolls out in kind
# without a real registry secret, while keeping the ServiceAccount and its
# serviceAccountName binding in the Deployment spec.
_patch = lambda manifest: any -> any {
    manifest | {
        if manifest.kind == "ServiceAccount":
            imagePullSecrets = []
        if manifest.kind == "Deployment":
            spec.template.spec.imagePullSecrets = []
    }
}

_module = h.wrap_component(
    "acceptance-webapp-sa",
    _namespace,
    [_patch(manifest) for manifest in _base.manifests],
    "3.10"
)

h.render_component(_namespace, _module)


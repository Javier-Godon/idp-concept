"""
ThirdPartyHelmSpec — Enhanced schema for deploying third-party Helm charts.
Generates a declarative Helm release manifest for use with Helm provider or helmfile.

Usage:
    import framework.models.modules.thirdparty_helm as th

    _spec = th.ThirdPartyHelmSpec {
        name = "questdb"
        namespace = "data"
        chart = "questdb/questdb"
        version = "0.32.0"
        values = { "persistence.size" = "50Gi" }
    }
    _manifest = th.build_thirdparty_helm(_spec)
"""

schema ThirdPartyHelmSpec:
    """Specification for deploying a third-party Helm chart."""
    name: str
    namespace: str
    chart: str
    version: str
    repository?: str
    values?: {str:str}
    valuesFiles?: [str]
    createNamespace: bool = True
    wait: bool = True
    timeout: str = "10m"

    check:
        len(version) > 0, "Helm chart version must be pinned — no empty strings"
        "latest" not in version, "version must not contain 'latest'"

build_thirdparty_helm = lambda spec: ThirdPartyHelmSpec -> any {
    {
        apiVersion = "helm.toolkit.fluxcd.io/v2beta1"
        kind = "HelmRelease"
        metadata = {
            name = spec.name
            namespace = spec.namespace
            labels = {
                "app.kubernetes.io/name" = spec.name
                "app.kubernetes.io/managed-by" = "idp-concept"
            }
        }
        spec = {
            chart = spec.chart
            version = spec.version
            if spec.repository:
                repository = spec.repository
            createNamespace = spec.createNamespace
            wait = spec.wait
            timeout = spec.timeout
            if spec.values:
                values = spec.values
            if spec.valuesFiles:
                valuesFiles = spec.valuesFiles
        }
    }
}

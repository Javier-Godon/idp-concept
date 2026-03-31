"""
Helm values extraction — extracts configurable parameters from component manifests.
Used by kcl_to_helm to generate values.yaml and Chart.yaml.

Phase 2 implementation: Strategy B — KCL generates values.yaml, templates are static.
"""
import models.modules.component
import custom.helm.helm

extract_helm_values = lambda comp: any -> {str:} {
    """Extract configurable Helm values from a component or accessory's manifests."""
    _deployments = [m for m in comp.manifests if m.kind == "Deployment"]
    _services = [m for m in comp.manifests if m.kind == "Service"]

    _deploy = _deployments[0] if _deployments else Undefined
    _svc = _services[0] if _services else Undefined

    _container = _deploy.spec.template.spec.containers[0] if _deploy is not Undefined else Undefined

    # Parse image into repository:tag
    _image_str = _container.image if _container is not Undefined else ""
    _image_parts = _image_str.split(":")
    _image_repo = _image_parts[0] if _image_parts else ""
    _image_tag = _image_parts[1] if len(_image_parts) > 1 else "latest"

    _pull_policy = _container.imagePullPolicy if _container is not Undefined and _container.imagePullPolicy is not Undefined else Undefined

    # Extract env vars with direct values only (skip secretKeyRef/configMapKeyRef)
    _env_list = _container.env if _container is not Undefined and _container.env is not Undefined else []
    _env_map = {e.name: e.value for e in _env_list if e.value is not Undefined}

    {
        if _deploy is not Undefined:
            replicaCount = _deploy.spec.replicas if _deploy.spec.replicas is not Undefined else 1
            image = {
                repository = _image_repo
                tag = _image_tag
                if _pull_policy is not Undefined:
                    pullPolicy = _pull_policy
            }
            if _container.resources is not Undefined:
                resources = _container.resources
            if _env_map:
                env = _env_map
        if _svc is not Undefined:
            service = {
                $type = _svc.spec.$type if _svc.spec.$type is not Undefined else "ClusterIP"
                port = _svc.spec.ports[0].port if _svc.spec.ports else 80
            }
    }
}

generate_chart = lambda comp: any, version: str -> helm.Chart {
    """Generate a Chart.yaml from a component or accessory."""
    helm.Chart {
        apiVersion = "v2"
        name = comp.name
        description = "Helm chart for ${comp.name}"
        $type = "application"
        version = version
        appVersion = version
    }
}

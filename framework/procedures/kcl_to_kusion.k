import models.component
import models.accessory
import models.k8snamespace

schema KusionResource:
    id: str
    type: str = "Kubernetes"
    attributes: any
    dependsOn?: [str] = []
    extensions?: {str:str}

schema KusionSpec:
    resources: [KusionResource]

# Helper function to wrap a manifest into a Kusion resource
kusion_spec_stream_single_manifest = lambda manifest: any, depends_on: [any] -> KusionResource {
    __kusion_resource = KusionResource {
        if manifest.metadata is Undefined or manifest.metadata.namespace is Undefined:
            id = "${manifest.apiVersion}:${manifest.kind}:${manifest.metadata.name}"
        else:
            id = "${manifest.apiVersion}:${manifest.kind}:${manifest.metadata.namespace}:${manifest.metadata.name}"
        if depends_on:
            dependsOn = ["${leader.apiVersion}:${leader.kind}:${leader.name}" if leader.namespace is Undefined else "${leader.apiVersion}:${leader.kind}:${leader.namespace}:${leader.name}" for parent in depends_on for leader in parent.leaders]
        
        attributes = manifest
    }
}

schema Dependency:
    manifest: any
    dependsOn: [any] = []

kusion_spec_stream_components = lambda components: [component.ComponentInstance] -> [KusionResource] {
    _dependencies = [Dependency {
        manifest = single_manifest
        dependsOn = component.dependsOn if component.dependsOn is not Undefined else []
    } for component in components for single_manifest in component.manifests]

    [kusion_spec_stream_single_manifest(dependency.manifest, dependency.dependsOn) for dependency in _dependencies]
}

kusion_spec_stream_accessories = lambda accessories: [accessory.AccessoryInstance] -> [KusionResource] {
    _dependencies = [Dependency {
        manifest = single_manifest
        dependsOn = accessory.dependsOn if accessory.dependsOn is not Undefined else []
    } for accessory in accessories for single_manifest in accessory.manifests]

    [kusion_spec_stream_single_manifest(dependency.manifest, dependency.dependsOn) for dependency in _dependencies]
}

kusion_spec_stream_namespaces = lambda namespaces: [k8snamespace.K8sNamespaceInstance] -> [KusionResource] {
    _dependencies = [Dependency {
        manifest = single_manifest
        dependsOn = []
    } for namespace in namespaces for single_manifest in namespace.manifests]

    [kusion_spec_stream_single_manifest(dependency.manifest, dependency.dependsOn) for dependency in _dependencies]
}

import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.gitops.gitopsstack
import manifests

get_components = lambda components: [component.ComponentInstance] -> [any] {
    [component.manifests for component in components] if components else []
}

get_caccessories = lambda accessories: [accessory.AccessoryInstance] -> [any] {
    [accessory.manifests for accessory in accessories] if accessories else []
}

get_namespaces = lambda namespaces: [k8snamespace.K8sNamespaceInstance] -> [any] {
    [namespace.manifests for namespace in namespaces] if namespaces else []
}

yaml_stream_stack = lambda input_stack: gitopsstack.GitOpsStack -> [any] {
    modules = []
    modules += get_components(input_stack.components)
    modules += get_caccessories(input_stack.accessories)
    modules += get_namespaces(input_stack.k8snamespaces)
    manifests.yaml_stream(modules)
}

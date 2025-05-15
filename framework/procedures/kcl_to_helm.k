import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.stack as stack
import manifests

generate_helm_components_templates_from_stack = lambda input_stack: stack.Stack -> any {
    modules = get_helm_components(input_stack.components)
    manifests.yaml_stream(modules)
}

get_helm_components = lambda components: [component.ComponentInstance ]-> [any] {
    [element.manifests for element in components] if components else []
}
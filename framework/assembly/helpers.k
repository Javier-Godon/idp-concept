"""
Stack Assembly helpers — reduce namespace and module instantiation boilerplate.

Usage in stack definitions:
    import framework.assembly.helpers as asm

    # Create a namespace instance
    _ns = asm.create_namespace("apps", instanceConfigurations)

    # Create a module instance with namespace dependency
    _mod = asm.create_module(MyModule, {
        name = "my-app"
        namespace = _ns.name
        asset = { image = "...", version = "..." }
        configurations = instanceConfigurations
        dependsOn = [_ns]
    })
"""
import models.modules.k8snamespace as k8snamespace

create_namespace = lambda name: str, configurations: any -> k8snamespace.K8sNamespaceInstance {
    k8snamespace.K8sNamespace {
        name = name
        configurations = configurations
    }.instance
}

create_namespace_from_config = lambda configField: str, configurations: any -> k8snamespace.K8sNamespaceInstance {
    _name = configurations[configField] if configurations[configField] else configField
    k8snamespace.K8sNamespace {
        name = _name
        configurations = configurations
    }.instance
}

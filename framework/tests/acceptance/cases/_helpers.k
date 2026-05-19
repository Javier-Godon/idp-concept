"""
Shared helpers for kind acceptance fixtures.

These keep acceptance cases on the IDP render path: template/module instance ->
RenderStack -> procedures.kcl_to_yaml.yaml_stream_stack.
"""

import models.modules.accessory as accessory
import models.modules.component as component
import models.modules.k8snamespace as k8sns
import models.manifests.renderstack as rs
import procedures.kcl_to_yaml as yaml_proc

build_namespace = lambda name: str -> k8sns.K8sNamespaceInstance {
    k8sns.K8sNamespace {
        name = name
        configurations = {}
    }.instance
}

wrap_accessory = lambda name: str, namespace: str, apiVersion: str, kind: str, resources: [any], version: str -> accessory.AccessoryInstance {
    accessory.Accessory {
        name = name
        namespace = namespace
        configurations = {}
        asset = {version = version}
        kind = "CRD"
        leaders = [accessory.AccessoryLeader {
            name = name
            kind = kind
            apiVersion = apiVersion
            namespace = namespace
        }]
        manifests = resources
        dependsOn = [build_namespace(namespace)]
    }.instance
}

wrap_component = lambda name: str, namespace: str, resources: [any], version: str -> component.ComponentInstance {
    component.Component {
        name = name
        namespace = namespace
        configurations = {}
        asset = {version = version}
        kind = "INFRASTRUCTURE"
        leaders = [component.ComponentLeader {
            name = name
            kind = "Deployment"
            apiVersion = "apps/v1"
            namespace = namespace
        }]
        manifests = resources
        dependsOn = [build_namespace(namespace)]
    }.instance
}

render_component = lambda namespace: str, module: component.ComponentInstance -> any {
    _namespace = build_namespace(namespace)
    _stack = rs.RenderStack {
        instanceConfigurations = {}
        k8snamespaces = [_namespace]
        components = [module]
    }
    yaml_proc.yaml_stream_stack(_stack)
}

render_accessory = lambda namespace: str, module: accessory.AccessoryInstance -> any {
    _namespace = build_namespace(namespace)
    _stack = rs.RenderStack {
        instanceConfigurations = {}
        k8snamespaces = [_namespace]
        accessories = [module]
    }
    yaml_proc.yaml_stream_stack(_stack)
}

render_stack = lambda namespaces: [str], components: [component.ComponentInstance], accessories: [accessory.AccessoryInstance] -> any {
    _namespaces = [build_namespace(namespace) for namespace in namespaces]
    _stack = rs.RenderStack {
        instanceConfigurations = {}
        k8snamespaces = _namespaces
        components = components
        accessories = accessories
    }
    yaml_proc.yaml_stream_stack(_stack)
}


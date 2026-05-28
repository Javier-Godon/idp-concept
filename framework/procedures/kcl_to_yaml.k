import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.manifests.renderstack
import models.release_notes as rn
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

get_release_notes = lambda notes: rn.ReleaseNotes = None -> [any] {
    [rn.build_release_notes_configmap(notes)] if notes and notes.includeInRender else []
}

yaml_stream_stack = lambda input_stack: renderstack.RenderStack -> [any] {
    modules = []
    modules += get_components(input_stack.components)
    modules += get_caccessories(input_stack.accessories)
    modules += get_namespaces(input_stack.k8snamespaces)
    modules += get_release_notes(input_stack.releaseNotes)
    manifests.yaml_stream(modules)
}

import models.modules.component
import models.modules.accessory
import models.modules.k8snamespace
import models.manifests.renderstack
import models.release_notes as rn
import manifests

_metadata_annotations = lambda meta: any -> {str:str} {
    {} if meta is Undefined else {
        if meta.owner is not Undefined:
            "koncept.io/owner" = meta.owner
        if meta.team is not Undefined:
            "koncept.io/team" = meta.team
        if meta.lifecycle is not Undefined:
            "koncept.io/lifecycle" = meta.lifecycle
        if meta.tier is not Undefined:
            "koncept.io/tier" = meta.tier
        if meta.sloTier is not Undefined:
            "koncept.io/slo-tier" = meta.sloTier
        if meta.criticality is not Undefined:
            "koncept.io/criticality" = meta.criticality
        if meta.dataClassification is not Undefined:
            "koncept.io/data-classification" = meta.dataClassification
        if meta.costCenter is not Undefined:
            "koncept.io/cost-center" = meta.costCenter
        if meta.runbook is not Undefined:
            "koncept.io/runbook" = meta.runbook
        if meta.support is not Undefined:
            "koncept.io/support-contact" = meta.support
    }
}

_metadata_labels = lambda meta: any -> {str:str} {
    {} if meta is Undefined or meta.labels is Undefined else meta.labels
}

_explicit_metadata_annotations = lambda meta: any -> {str:str} {
    {} if meta is Undefined or meta.annotations is Undefined else meta.annotations
}

apply_stack_metadata = lambda manifest: any, meta: any -> any {
    _labels = _metadata_labels(meta)
    _annotations = _metadata_annotations(meta) | _explicit_metadata_annotations(meta)
    manifest if not _labels and not _annotations else manifest | {
        metadata.labels = _labels | (manifest.metadata.labels if manifest.metadata.labels is not Undefined else {})
        metadata.annotations = _annotations | (manifest.metadata.annotations if manifest.metadata.annotations is not Undefined else {})
    }
}

get_components = lambda components: [component.ComponentInstance] -> [any] {
    [component.manifests for component in components] if components else []
}

get_components_with_metadata = lambda components: [component.ComponentInstance], meta: any -> [any] {
    [[apply_stack_metadata(manifest, meta) for manifest in component.manifests] for component in components] if components else []
}

get_caccessories = lambda accessories: [accessory.AccessoryInstance] -> [any] {
    [accessory.manifests for accessory in accessories] if accessories else []
}

get_caccessories_with_metadata = lambda accessories: [accessory.AccessoryInstance], meta: any -> [any] {
    [[apply_stack_metadata(manifest, meta) for manifest in accessory.manifests] for accessory in accessories] if accessories else []
}

get_namespaces = lambda namespaces: [k8snamespace.K8sNamespaceInstance] -> [any] {
    [namespace.manifests for namespace in namespaces] if namespaces else []
}

get_namespaces_with_metadata = lambda namespaces: [k8snamespace.K8sNamespaceInstance], meta: any -> [any] {
    [[apply_stack_metadata(manifest, meta) for manifest in namespace.manifests] for namespace in namespaces] if namespaces else []
}

get_release_notes = lambda notes: rn.ReleaseNotes = None -> [any] {
    [rn.build_release_notes_configmap(notes)] if notes and notes.includeInRender else []
}

get_release_notes_with_metadata = lambda meta: any, notes: rn.ReleaseNotes = None -> [any] {
    [apply_stack_metadata(note, meta) for note in get_release_notes(notes)]
}

yaml_stream_stack = lambda input_stack: renderstack.RenderStack -> [any] {
    modules = []
    modules += get_components_with_metadata(input_stack.components, input_stack.metadata)
    modules += get_caccessories_with_metadata(input_stack.accessories, input_stack.metadata)
    modules += get_namespaces_with_metadata(input_stack.k8snamespaces, input_stack.metadata)
    modules += get_release_notes_with_metadata(input_stack.metadata, input_stack.releaseNotes)
    manifests.yaml_stream(modules)
}

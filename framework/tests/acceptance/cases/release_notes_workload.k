"""
Acceptance fixture: release notes ConfigMap through yaml_stream_stack.
"""
import ._helpers as h
import models.manifests.renderstack as renderstack
import models.release_notes as rn
import procedures.kcl_to_yaml as yaml_proc

_namespace = "idp-acceptance-release-notes"
_stack = renderstack.RenderStack {
    instanceConfigurations = {}
    components = []
    accessories = []
    k8snamespaces = [h.build_namespace(_namespace)]
    releaseNotes = rn.ReleaseNotes {
        name = "acceptance-release"
        version = "1.0.0"
        namespace = _namespace
        entries = [rn.ReleaseNoteEntry {category = "added", text = "Release notes are included in rendered output."}]
    }
}

yaml_proc.yaml_stream_stack(_stack)

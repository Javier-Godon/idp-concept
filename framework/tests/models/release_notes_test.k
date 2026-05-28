import models.release_notes as rn

test_release_notes_markdown = lambda {
    _notes = rn.ReleaseNotes {
        name = "erp-back"
        version = "1.2.3"
        date = "2026-05-28"
        summary = "Test release"
        entries = [
            rn.ReleaseNoteEntry {category = "added", text = "New dashboard"}
            rn.ReleaseNoteEntry {category = "fixed", text = "Deployment order"}
        ]
    }
    _markdown = rn.render_markdown(_notes)
    assert "# erp-back 1.2.3" in _markdown
    assert "**added**: New dashboard" in _markdown
}

test_release_notes_configmap = lambda {
    _cm = rn.build_release_notes_configmap(rn.ReleaseNotes {
        name = "erp-back"
        version = "1.2.3"
        namespace = "apps"
    })
    assert _cm.kind == "ConfigMap"
    assert _cm.metadata.name == "erp-back-release-notes"
    assert _cm.metadata.labels["app.kubernetes.io/version"] == "1.2.3"
}

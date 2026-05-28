"""
Release notes metadata and render helpers.

Release notes follow a small Keep-a-Changelog-inspired shape so factories can
carry human-readable changes next to generated deployment artifacts.
"""

schema ReleaseNoteEntry:
    category: str
    text: str

    check:
        category in ["added", "changed", "deprecated", "removed", "fixed", "security", "known-issue"], "release note category must follow standard changelog categories"
        len(text) > 0, "release note text must not be empty"

schema ReleaseNotes:
    name: str
    version: str
    namespace?: str = "default"
    date?: str
    entries?: [ReleaseNoteEntry] = []
    summary?: str
    includeInRender?: bool = True

    check:
        len(name) > 0, "release notes name must not be empty"
        len(version) > 0, "release notes version must not be empty"

_markdown_entry = lambda entry: ReleaseNoteEntry -> str {
    "- **${entry.category}**: ${entry.text}"
}

render_markdown = lambda notes: ReleaseNotes -> str {
    _header = "# ${notes.name} ${notes.version}\n"
    _date = "\n_Date: ${notes.date}_\n" if notes.date else ""
    _summary = "\n${notes.summary}\n" if notes.summary else ""
    _entries = "\n" + "\n".join([_markdown_entry(e) for e in notes.entries]) + "\n" if notes.entries else "\nNo release note entries were provided.\n"
    _header + _date + _summary + _entries
}

build_release_notes_configmap = lambda notes: ReleaseNotes -> any {
    {
        apiVersion = "v1"
        kind = "ConfigMap"
        metadata = {
            name = "${notes.name}-release-notes"
            namespace = notes.namespace
            labels = {
                "app.kubernetes.io/name" = notes.name
                "app.kubernetes.io/component" = "release-notes"
                "app.kubernetes.io/managed-by" = "idp-concept"
                "app.kubernetes.io/version" = notes.version
            }
        }
        data = {
            "RELEASE_NOTES.md" = render_markdown(notes)
        }
    }
}

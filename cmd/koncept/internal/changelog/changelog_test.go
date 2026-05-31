package changelog

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestRenderMarkdownGroupsInStableOrder(t *testing.T) {
	out, err := RenderMarkdown("v1.2.3", time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC), []Fragment{
		{Type: "fixed", Summary: "Fix render drift diff", Owner: "platform", Issue: "IDP-2"},
		{Type: "added", Summary: "Add changelog fragments", Owner: "platform", Issue: "IDP-1"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(out, "## [v1.2.3] - 2026-05-31") {
		t.Fatalf("missing release header:\n%s", out)
	}
	if strings.Index(out, "### Added") > strings.Index(out, "### Fixed") {
		t.Fatalf("categories should follow Keep-a-Changelog order:\n%s", out)
	}
	if !strings.Contains(out, "- Add changelog fragments (owner: platform; issue: IDP-1)") {
		t.Fatalf("missing rendered metadata:\n%s", out)
	}
}

func TestValidateRequiresOwner(t *testing.T) {
	err := Validate(Fragment{Type: "added", Summary: "Add feature"})
	if err == nil || !strings.Contains(err.Error(), "owner") {
		t.Fatalf("expected missing owner error, got %v", err)
	}
}

func TestValidateRejectsUnknownType(t *testing.T) {
	err := Validate(Fragment{Type: "misc", Summary: "Add feature", Owner: "platform"})
	if err == nil || !strings.Contains(err.Error(), "unsupported type") {
		t.Fatalf("expected unsupported type error, got %v", err)
	}
}

func TestWriteFragmentRefusesOverwrite(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "entry.yaml")
	fragment := Fragment{Type: "changed", Summary: "Change behavior", Owner: "platform"}
	if err := WriteFragment(path, fragment); err != nil {
		t.Fatalf("write fragment: %v", err)
	}
	if err := WriteFragment(path, fragment); err == nil || !strings.Contains(err.Error(), "already exists") {
		t.Fatalf("expected overwrite refusal, got %v", err)
	}
}

func TestReadDirSortsFragments(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "b.yaml"), []byte("type: fixed\nsummary: B\nowner: platform\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "a.yaml"), []byte("type: added\nsummary: A\nowner: platform\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	fragments, err := ReadDir(dir)
	if err != nil {
		t.Fatalf("read dir: %v", err)
	}
	if len(fragments) != 2 || !strings.HasSuffix(fragments[0].File, "a.yaml") || !strings.HasSuffix(fragments[1].File, "b.yaml") {
		t.Fatalf("fragments not sorted by file: %+v", fragments)
	}
}

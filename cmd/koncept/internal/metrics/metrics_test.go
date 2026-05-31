package metrics

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCategorize(t *testing.T) {
	cases := map[string]string{
		"":                                    "",
		"cannot find the module models.stack": "module-resolution",
		"render.k not found in factory":       "factory-setup",
		"policy check failed: privileged":     "policy",
		"schema check failed: expected int":   "validation",
		"open x: permission denied":           "filesystem",
		"some unexpected boom":                "validation", // contains "expected"
		"totally novel failure":               "other",
	}
	for msg, want := range cases {
		var err error
		if msg != "" {
			err = errors.New(msg)
		}
		if got := Categorize(err); got != want {
			t.Errorf("Categorize(%q) = %q, want %q", msg, got, want)
		}
	}
}

func TestRecorderDisabledIsNoop(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "metrics.jsonl")
	r := NewRecorder(false, path, "test")
	r.Record("render", "yaml", time.Second, nil)
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("expected no file when disabled, stat err = %v", err)
	}
	if r.Enabled() {
		t.Fatal("disabled recorder reported enabled")
	}
}

func TestRecorderRecordsAndLoads(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sub", "metrics.jsonl")
	r := NewRecorder(true, path, "1.2.3")

	r.Record("render", "yaml", 100*time.Millisecond, nil)
	r.Record("render", "argocd", 200*time.Millisecond, errors.New("cannot find the module x"))
	r.Record("validate", "", 50*time.Millisecond, nil)

	events, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(events) != 3 {
		t.Fatalf("expected 3 events, got %d", len(events))
	}
	if events[1].ErrorCategory != "module-resolution" {
		t.Errorf("expected module-resolution category, got %q", events[1].ErrorCategory)
	}
	if events[0].Version != "1.2.3" {
		t.Errorf("expected version recorded, got %q", events[0].Version)
	}
}

func TestLoadMissingFile(t *testing.T) {
	events, err := Load(filepath.Join(t.TempDir(), "nope.jsonl"))
	if err != nil {
		t.Fatalf("expected nil error for missing file, got %v", err)
	}
	if len(events) != 0 {
		t.Fatalf("expected 0 events, got %d", len(events))
	}
}

func TestLoadSkipsMalformedLines(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "m.jsonl")
	content := `{"command":"render","format":"yaml","durationMs":10,"success":true}
not-json
{"command":"validate","durationMs":5,"success":false,"errorCategory":"validation"}
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	events, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(events) != 2 {
		t.Fatalf("expected 2 valid events, got %d", len(events))
	}
}

func TestSummarize(t *testing.T) {
	base := time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC)
	events := []Event{
		{Timestamp: base, Command: "render", Format: "yaml", DurationMs: 100, Success: true},
		{Timestamp: base.Add(time.Minute), Command: "render", Format: "yaml", DurationMs: 300, Success: false, ErrorCategory: "validation"},
		{Timestamp: base.Add(2 * time.Minute), Command: "render", Format: "argocd", DurationMs: 200, Success: true},
		{Timestamp: base.Add(3 * time.Minute), Command: "validate", DurationMs: 50, Success: true},
	}
	s := Summarize(events)
	if s.Total != 4 {
		t.Errorf("Total = %d, want 4", s.Total)
	}
	if s.Failures != 1 {
		t.Errorf("Failures = %d, want 1", s.Failures)
	}
	if s.ByFormat["yaml"] != 2 || s.ByFormat["argocd"] != 1 {
		t.Errorf("ByFormat = %v", s.ByFormat)
	}
	if s.ByErrorCat["validation"] != 1 {
		t.Errorf("ByErrorCat = %v", s.ByErrorCat)
	}
	if len(s.Commands) != 2 {
		t.Fatalf("expected 2 command stats, got %d", len(s.Commands))
	}
	// Commands sorted: render, validate
	render := s.Commands[0]
	if render.Command != "render" || render.Total != 3 || render.Failures != 1 {
		t.Errorf("render stat = %+v", render)
	}
	if render.AvgMs != 200 {
		t.Errorf("render AvgMs = %d, want 200", render.AvgMs)
	}
	if s.FirstSeen != base || s.LastSeen != base.Add(3*time.Minute) {
		t.Errorf("time window wrong: first=%v last=%v", s.FirstSeen, s.LastSeen)
	}
}

func TestSummarizeEmpty(t *testing.T) {
	s := Summarize(nil)
	if s.Total != 0 || len(s.Commands) != 0 {
		t.Fatalf("expected empty summary, got %+v", s)
	}
}

func TestEnabledFromEnv(t *testing.T) {
	t.Setenv("KONCEPT_METRICS", "1")
	if !EnabledFromEnv() {
		t.Error("expected enabled for '1'")
	}
	t.Setenv("KONCEPT_METRICS", "off")
	if EnabledFromEnv() {
		t.Error("expected disabled for 'off'")
	}
}

func TestDefaultPathOverride(t *testing.T) {
	t.Setenv("KONCEPT_METRICS_FILE", "/tmp/custom-metrics.jsonl")
	if got := DefaultPath(); got != "/tmp/custom-metrics.jsonl" {
		t.Errorf("DefaultPath = %q", got)
	}
}

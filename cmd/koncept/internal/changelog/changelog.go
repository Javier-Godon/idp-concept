// Package changelog implements small release-note fragments for framework and
// platform changes. It intentionally avoids external tooling so CI can validate
// changelog intent with the same Go CLI used for rendering and policy checks.
package changelog

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const DateLayout = "2006-01-02"

var CategoryOrder = []string{"added", "changed", "deprecated", "removed", "fixed", "security", "known-issue"}

var categoryHeadings = map[string]string{
	"added":       "Added",
	"changed":     "Changed",
	"deprecated":  "Deprecated",
	"removed":     "Removed",
	"fixed":       "Fixed",
	"security":    "Security",
	"known-issue": "Known Issues",
}

// Fragment is one reviewable changelog entry, normally stored as a YAML file
// under .changes/unreleased/.
type Fragment struct {
	Type    string `yaml:"type"`
	Summary string `yaml:"summary"`
	Owner   string `yaml:"owner"`
	Issue   string `yaml:"issue,omitempty"`
	Details string `yaml:"details,omitempty"`
	File    string `yaml:"-"`
}

// ReadDir loads all YAML fragments from dir. A missing directory is treated as
// an empty set so repositories can enable the command before the first fragment.
func ReadDir(dir string) ([]Fragment, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("read changelog fragments dir %s: %w", dir, err)
	}

	var fragments []Fragment
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(name, ".yaml") && !strings.HasSuffix(name, ".yml") {
			continue
		}
		path := filepath.Join(dir, name)
		fragment, err := ReadFile(path)
		if err != nil {
			return nil, err
		}
		fragments = append(fragments, fragment)
	}
	sort.Slice(fragments, func(i, j int) bool {
		return fragments[i].File < fragments[j].File
	})
	return fragments, nil
}

// ReadFile loads one changelog fragment file.
func ReadFile(path string) (Fragment, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Fragment{}, fmt.Errorf("read changelog fragment %s: %w", path, err)
	}
	var fragment Fragment
	if err := yaml.Unmarshal(data, &fragment); err != nil {
		return Fragment{}, fmt.Errorf("parse changelog fragment %s: %w", path, err)
	}
	fragment.File = path
	if err := Validate(fragment); err != nil {
		return Fragment{}, err
	}
	return fragment, nil
}

// Validate checks that a fragment is actionable and attributable.
func Validate(fragment Fragment) error {
	var missing []string
	if strings.TrimSpace(fragment.Type) == "" {
		missing = append(missing, "type")
	}
	if strings.TrimSpace(fragment.Summary) == "" {
		missing = append(missing, "summary")
	}
	if strings.TrimSpace(fragment.Owner) == "" {
		missing = append(missing, "owner")
	}
	if len(missing) > 0 {
		return fmt.Errorf("changelog fragment %s missing required field(s): %s", fragmentLabel(fragment), strings.Join(missing, ", "))
	}
	if _, ok := categoryHeadings[fragment.Type]; !ok {
		return fmt.Errorf("changelog fragment %s has unsupported type %q (allowed: %s)",
			fragmentLabel(fragment), fragment.Type, strings.Join(CategoryOrder, ", "))
	}
	return nil
}

// RenderMarkdown renders fragments as a Keep-a-Changelog style release section.
func RenderMarkdown(version string, date time.Time, fragments []Fragment) (string, error) {
	version = strings.TrimSpace(version)
	if version == "" {
		return "", fmt.Errorf("version is required")
	}
	for _, fragment := range fragments {
		if err := Validate(fragment); err != nil {
			return "", err
		}
	}

	grouped := map[string][]Fragment{}
	for _, fragment := range fragments {
		grouped[fragment.Type] = append(grouped[fragment.Type], fragment)
	}
	for category := range grouped {
		sort.Slice(grouped[category], func(i, j int) bool {
			return grouped[category][i].Summary < grouped[category][j].Summary
		})
	}

	var b strings.Builder
	fmt.Fprintf(&b, "## [%s] - %s\n\n", version, date.UTC().Format(DateLayout))
	if len(fragments) == 0 {
		b.WriteString("_No changelog fragments were present for this release._\n")
		return b.String(), nil
	}

	for _, category := range CategoryOrder {
		items := grouped[category]
		if len(items) == 0 {
			continue
		}
		fmt.Fprintf(&b, "### %s\n\n", categoryHeadings[category])
		for _, item := range items {
			fmt.Fprintf(&b, "- %s", strings.TrimSpace(item.Summary))
			metadata := []string{"owner: " + strings.TrimSpace(item.Owner)}
			if strings.TrimSpace(item.Issue) != "" {
				metadata = append(metadata, "issue: "+strings.TrimSpace(item.Issue))
			}
			fmt.Fprintf(&b, " (%s)", strings.Join(metadata, "; "))
			if strings.TrimSpace(item.Details) != "" {
				fmt.Fprintf(&b, " — %s", strings.TrimSpace(item.Details))
			}
			b.WriteString("\n")
		}
		b.WriteString("\n")
	}
	return b.String(), nil
}

// WriteFragment writes a new fragment and refuses to overwrite existing files.
func WriteFragment(path string, fragment Fragment) error {
	if err := Validate(fragment); err != nil {
		return err
	}
	data, err := yaml.Marshal(fragment)
	if err != nil {
		return fmt.Errorf("marshal changelog fragment: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("create changelog fragment dir: %w", err)
	}
	return writeNewFile(path, data)
}

func writeNewFile(path string, data []byte) error {
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
	if err != nil {
		if os.IsExist(err) {
			return fmt.Errorf("changelog fragment already exists: %s", path)
		}
		return fmt.Errorf("create changelog fragment %s: %w", path, err)
	}
	defer file.Close()
	if _, err := bytes.NewReader(data).WriteTo(file); err != nil {
		return fmt.Errorf("write changelog fragment %s: %w", path, err)
	}
	return nil
}

func fragmentLabel(fragment Fragment) string {
	if fragment.File != "" {
		return fragment.File
	}
	return "<inline>"
}

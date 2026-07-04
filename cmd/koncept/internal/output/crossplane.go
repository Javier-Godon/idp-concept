package output

import (
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// WriteCrossplane writes rendered Crossplane KCL output (a YAML document with
// xrd/composition/xr/prerequisites/managed_resources keys) into the layout
// consumed by `crossplane render`, `kubectl apply`, and the runtime check
// helpers in internal/crossplane/runtime.go:
//
//	<outDir>/crossplane/xrd.yaml
//	<outDir>/crossplane/composition.yaml
//	<outDir>/crossplane/xr.yaml
//	<outDir>/crossplane/prerequisites/infrastructure.yaml   (all pkg resources)
//	<outDir>/crossplane/prerequisites/providers.yaml         (Provider + ProviderConfig)
//	<outDir>/crossplane/prerequisites/functions.yaml         (Function packages)
//	<outDir>/crossplane/managed_resources/<claim>.yaml       (curated Track 1 Claims)
func WriteCrossplane(rendered string, outDir string) error {
	var doc map[string]any
	if err := yaml.Unmarshal([]byte(rendered), &doc); err != nil {
		return fmt.Errorf("parse crossplane output: %w", err)
	}

	crossplaneDir := filepath.Join(outDir, "crossplane")
	if err := ensureDir(crossplaneDir); err != nil {
		return err
	}

	for key, filename := range map[string]string{
		"xrd":         "xrd.yaml",
		"composition": "composition.yaml",
		"xr":          "xr.yaml",
	} {
		section, ok := doc[key].(map[string]any)
		if !ok {
			return fmt.Errorf("crossplane output missing %q section", key)
		}
		if err := writeYAMLDoc(filepath.Join(crossplaneDir, filename), section); err != nil {
			return err
		}
	}

	prereqs := toMapSlice(doc["prerequisites"])
	if len(prereqs) == 0 {
		return errors.New("crossplane output missing prerequisites section")
	}
	prereqDir := filepath.Join(crossplaneDir, "prerequisites")
	if err := ensureDir(prereqDir); err != nil {
		return err
	}
	if err := writeYAMLMultiDoc(filepath.Join(prereqDir, "infrastructure.yaml"), prereqs); err != nil {
		return err
	}

	providers := []map[string]any{}
	functions := []map[string]any{}
	for _, r := range prereqs {
		switch mapString(r, "kind") {
		case "Provider", "ProviderConfig":
			providers = append(providers, r)
		case "Function":
			functions = append(functions, r)
		}
	}
	if len(providers) > 0 {
		if err := writeYAMLMultiDoc(filepath.Join(prereqDir, "providers.yaml"), providers); err != nil {
			return err
		}
	}
	if len(functions) > 0 {
		if err := writeYAMLMultiDoc(filepath.Join(prereqDir, "functions.yaml"), functions); err != nil {
			return err
		}
	}

	managed := toMapSlice(doc["managed_resources"])
	if len(managed) > 0 {
		managedDir := filepath.Join(crossplaneDir, "managed_resources")
		if err := ensureDir(managedDir); err != nil {
			return err
		}
		for _, resource := range managed {
			name := claimFilename(resource)
			if err := writeYAMLDoc(filepath.Join(managedDir, name), resource); err != nil {
				return err
			}
		}
	}

	return nil
}

func claimFilename(resource map[string]any) string {
	kind := strings.ToLower(mapString(resource, "kind"))
	name := ""
	if meta, ok := resource["metadata"].(map[string]any); ok {
		name = mapString(meta, "name")
	}
	if kind == "" {
		kind = "resource"
	}
	if name == "" {
		name = "unnamed"
	}
	return fmt.Sprintf("%s-%s.yaml", kind, name)
}

func writeYAMLDoc(path string, doc any) error {
	data, err := yaml.Marshal(doc)
	if err != nil {
		return fmt.Errorf("marshal %s: %w", path, err)
	}
	return WriteYAML(string(data), path)
}

func writeYAMLMultiDoc(path string, docs []map[string]any) error {
	parts := make([]string, 0, len(docs))
	for _, doc := range docs {
		b, err := yaml.Marshal(doc)
		if err != nil {
			return fmt.Errorf("marshal document for %s: %w", path, err)
		}
		parts = append(parts, strings.TrimRight(string(b), "\n"))
	}
	content := strings.Join(parts, "\n---\n") + "\n"
	return WriteYAML(content, path)
}

func toMapSlice(v any) []map[string]any {
	items, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]map[string]any, 0, len(items))
	for _, item := range items {
		if m, ok := item.(map[string]any); ok {
			out = append(out, m)
		}
	}
	return out
}

func mapString(m map[string]any, key string) string {
	v, _ := m[key].(string)
	return v
}

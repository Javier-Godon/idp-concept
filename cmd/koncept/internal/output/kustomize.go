package output

import (
	"errors"
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// WriteKustomize writes Kustomize output into:
//
//	<outDir>/base/kustomization.yaml   (from kustomizeData)
//	<outDir>/base/<kind>-<name>.yaml   (one file per manifest, split from manifestsData)
//
// kustomizeData is expected to be a single YAML document produced by
// procedures.kcl_to_kustomize.generate_kustomization_from_stack (contains
// apiVersion=kustomize.config.k8s.io/v1beta1 and a `resources:` list).
//
// manifestsData is the raw multi-document Kubernetes YAML stream produced by
// procedures.kcl_to_yaml (same as `koncept render yaml`).
func WriteKustomize(kustomizeData string, manifestsData string, outDir string) error {
	baseDir := filepath.Join(outDir, "base")
	if err := ensureDir(baseDir); err != nil {
		return err
	}

	if err := WriteYAML(kustomizeData, filepath.Join(baseDir, "kustomization.yaml")); err != nil {
		return err
	}

	manifests, err := splitYAMLDocuments(manifestsData)
	if err != nil {
		return fmt.Errorf("split kustomize manifests: %w", err)
	}
	if len(manifests) == 0 {
		return errors.New("kustomize manifests stream is empty")
	}

	for _, entry := range manifests {
		filename := manifestFilename(entry.doc)
		if err := WriteYAML(entry.serialized, filepath.Join(baseDir, filename)); err != nil {
			return err
		}
	}

	return nil
}

type yamlDoc struct {
	serialized string
	doc        map[string]any
}

// splitYAMLDocuments splits a multi-doc YAML stream into individual documents.
// Each document is round-tripped through the YAML encoder, so formatting is
// normalized and comments are dropped in the serialized form.
func splitYAMLDocuments(stream string) ([]yamlDoc, error) {
	docs := []yamlDoc{}
	dec := yaml.NewDecoder(strings.NewReader(stream))
	for {
		var raw map[string]any
		if err := dec.Decode(&raw); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, err
		}
		if len(raw) == 0 {
			continue
		}
		encoded, err := yaml.Marshal(raw)
		if err != nil {
			return nil, err
		}
		docs = append(docs, yamlDoc{serialized: string(encoded), doc: raw})
	}
	return docs, nil
}

func manifestFilename(doc map[string]any) string {
	kind := strings.ToLower(mapString(doc, "kind"))
	if kind == "" {
		kind = "unknown"
	}
	name := "unnamed"
	namespace := ""
	if meta, ok := doc["metadata"].(map[string]any); ok {
		if n := mapString(meta, "name"); n != "" {
			name = n
		}
		namespace = mapString(meta, "namespace")
	}
	if namespace != "" {
		return fmt.Sprintf("%s-%s-%s.yaml", namespace, kind, name)
	}
	return fmt.Sprintf("%s-%s.yaml", kind, name)
}

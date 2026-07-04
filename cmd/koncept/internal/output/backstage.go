package output

import (
	"errors"
	"fmt"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// WriteBackstage writes rendered Backstage KCL output (a YAML document with
// metadata and entities keys) as a multi-document catalog-info.yaml file:
//
//	<outDir>/backstage/catalog-info.yaml
func WriteBackstage(rendered string, outDir string) error {
	var doc map[string]any
	if err := yaml.Unmarshal([]byte(rendered), &doc); err != nil {
		return fmt.Errorf("parse backstage output: %w", err)
	}

	entities := toMapSlice(doc["entities"])
	if len(entities) == 0 {
		return errors.New("backstage output missing entities section")
	}

	backstageDir := filepath.Join(outDir, "backstage")
	if err := ensureDir(backstageDir); err != nil {
		return err
	}
	return writeYAMLMultiDoc(filepath.Join(backstageDir, "catalog-info.yaml"), entities)
}

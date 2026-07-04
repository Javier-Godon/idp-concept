// Package output writes rendered KCL results to disk in the layout each
// downstream tool (ArgoCD, Helm, Helmfile, Kustomize, Crossplane, Backstage,
// ...) expects.
//
// All Write* functions take the raw string produced by factory.Render as their
// data input(s). Splitting per output format lives in this package so that CLI
// command files stay thin.
package output

import (
	"fmt"
	"os"
	"path/filepath"
)

// WriteYAML writes content to outFile, creating parent directories as needed.
func WriteYAML(content string, outFile string) error {
	if err := ensureDir(filepath.Dir(outFile)); err != nil {
		return err
	}
	if err := os.WriteFile(outFile, []byte(content), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", outFile, err)
	}
	return nil
}

func ensureDir(dir string) error {
	if dir == "" || dir == "." {
		return nil
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create directory %s: %w", dir, err)
	}
	return nil
}

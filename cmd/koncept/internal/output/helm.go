package output

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// WriteHelmCharts writes Helm chart data (Chart.yaml + values.yaml per module)
// produced by procedures.kcl_to_helm.generate_charts_from_stack.
//
// helmData is a YAML stream that decodes into a list of items with `chart`
// (Chart.yaml struct) and `values` (values.yaml dict) keys. templatesDir, when
// present on disk, is copied into each chart's templates/ directory so the
// resulting layout can be consumed directly by `helm` / `helmfile`.
//
//	<outDir>/<chartName>/Chart.yaml
//	<outDir>/<chartName>/values.yaml
//	<outDir>/<chartName>/templates/*   (copied from templatesDir when present)
func WriteHelmCharts(helmData string, outDir string, templatesDir string) error {
	charts, err := decodeHelmCharts(helmData)
	if err != nil {
		return err
	}
	if len(charts) == 0 {
		return errors.New("helm output is empty (no charts)")
	}

	for _, entry := range charts {
		chart, _ := entry["chart"].(map[string]any)
		values, _ := entry["values"].(map[string]any)
		if chart == nil {
			return errors.New("helm chart entry missing chart section")
		}
		name := mapString(chart, "name")
		if name == "" {
			return errors.New("helm chart entry missing metadata.name")
		}

		chartDir := filepath.Join(outDir, name)
		if err := ensureDir(chartDir); err != nil {
			return err
		}

		if err := writeYAMLDoc(filepath.Join(chartDir, "Chart.yaml"), chart); err != nil {
			return err
		}
		valuesDoc := values
		if valuesDoc == nil {
			valuesDoc = map[string]any{}
		}
		if err := writeYAMLDoc(filepath.Join(chartDir, "values.yaml"), valuesDoc); err != nil {
			return err
		}

		if templatesDir != "" {
			if info, err := os.Stat(templatesDir); err == nil && info.IsDir() {
				if err := copyTemplatesDir(templatesDir, filepath.Join(chartDir, "templates")); err != nil {
					return err
				}
			}
		}
	}

	return nil
}

func decodeHelmCharts(stream string) ([]map[string]any, error) {
	dec := yaml.NewDecoder(strings.NewReader(stream))
	out := []map[string]any{}
	for {
		var doc any
		if err := dec.Decode(&doc); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, fmt.Errorf("parse helm output: %w", err)
		}
		switch v := doc.(type) {
		case map[string]any:
			out = append(out, v)
		case []any:
			for _, item := range v {
				if m, ok := item.(map[string]any); ok {
					out = append(out, m)
				}
			}
		}
	}
	return out, nil
}

func copyTemplatesDir(src string, dst string) error {
	if err := ensureDir(dst); err != nil {
		return err
	}
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return ensureDir(target)
		}
		return copyFile(path, target, info.Mode())
	})
}

func copyFile(src string, dst string, mode os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("open %s: %w", src, err)
	}
	defer in.Close()

	if err := ensureDir(filepath.Dir(dst)); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, mode)
	if err != nil {
		return fmt.Errorf("create %s: %w", dst, err)
	}
	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return fmt.Errorf("copy %s -> %s: %w", src, dst, err)
	}
	return nil
}

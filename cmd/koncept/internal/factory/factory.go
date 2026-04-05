package factory

import (
	"fmt"
	"os"
	"path/filepath"

	kcl "kcl-lang.io/kcl-go"
)

// Render executes a KCL render with the given output format.
func Render(factoryDir string, outputFormat string) (string, error) {
	renderFile := filepath.Join(factoryDir, "render.k")
	if _, err := os.Stat(renderFile); os.IsNotExist(err) {
		return "", fmt.Errorf("render.k not found in %s", factoryDir)
	}

	absDir, err := filepath.Abs(factoryDir)
	if err != nil {
		return "", fmt.Errorf("cannot resolve factory dir: %w", err)
	}

	result, err := kcl.RunFiles([]string{renderFile},
		kcl.WithWorkDir(absDir),
		kcl.WithOptions("output="+outputFormat),
		kcl.WithSortKeys(true),
	)
	if err != nil {
		return "", fmt.Errorf("KCL render failed: %w", err)
	}
	return result.GetRawYamlResult(), nil
}

// Validate compiles factory_seed.k without rendering to check for errors.
func Validate(factoryDir string, seedFile string) error {
	seedPath := filepath.Join(factoryDir, seedFile)
	if _, err := os.Stat(seedPath); os.IsNotExist(err) {
		return fmt.Errorf("%s not found in %s", seedFile, factoryDir)
	}

	absDir, err := filepath.Abs(factoryDir)
	if err != nil {
		return fmt.Errorf("cannot resolve factory dir: %w", err)
	}

	_, err = kcl.RunFiles([]string{seedPath},
		kcl.WithWorkDir(absDir),
	)
	return err
}

// RunTest runs KCL tests in the given directory.
func RunTest(testDir string) (string, int, error) {
	absDir, err := filepath.Abs(testDir)
	if err != nil {
		return "", 0, fmt.Errorf("cannot resolve test dir: %w", err)
	}

	result, err := kcl.Test(&kcl.TestOptions{
		PkgList: []string{absDir + "/..."},
	})
	if err != nil {
		return "", 0, err
	}

	total := len(result.Info)
	failed := 0
	output := ""
	for _, info := range result.Info {
		status := "PASS"
		if info.Fail() {
			status = "FAIL"
			failed++
		}
		output += fmt.Sprintf("  %s: %s %s\n", status, info.Name, info.ErrMessage)
	}

	output += fmt.Sprintf("\n  Total: %d, Passed: %d, Failed: %d\n", total, total-failed, failed)

	return output, failed, nil
}

// Format formats all KCL files in the given path.
func Format(path string) ([]string, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("cannot resolve path: %w", err)
	}
	return kcl.FormatPath(absPath)
}

// Lint lints all KCL files in the given paths.
func Lint(paths []string) ([]string, error) {
	absPaths := make([]string, len(paths))
	for i, p := range paths {
		abs, err := filepath.Abs(p)
		if err != nil {
			return nil, fmt.Errorf("cannot resolve path %s: %w", p, err)
		}
		absPaths[i] = abs
	}
	return kcl.LintPath(absPaths)
}

// ListDeps lists dependency files for the given working directory.
func ListDeps(workDir string) ([]string, error) {
	absDir, err := filepath.Abs(workDir)
	if err != nil {
		return nil, fmt.Errorf("cannot resolve dir: %w", err)
	}
	return kcl.ListDepFiles(absDir, nil)
}

// HasRenderK checks if a render.k file exists in the factory directory.
func HasRenderK(factoryDir string) bool {
	_, err := os.Stat(filepath.Join(factoryDir, "render.k"))
	return err == nil
}

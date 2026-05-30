package factory

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	kcl "kcl-lang.io/kcl-go"
)

var localDependencyRE = regexp.MustCompile(`^([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*\{[^}]*path\s*=\s*["']([^"']+)["']`)
var registryDependencyRE = regexp.MustCompile(`^([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*["']([^"']+)["']`)

// Render executes a KCL render with the given output format.
func Render(factoryDir string, outputFormat string) (string, error) {
	moduleRoot, renderFile, err := resolveKCLFile(factoryDir, "render.k")
	if err != nil {
		return "", err
	}

	options := []kcl.Option{
		kcl.WithWorkDir(moduleRoot),
		kcl.WithOptions(append([]string{"output=" + outputFormat}, ConventionOptions(factoryDir)...)...),
		kcl.WithSortKeys(true),
	}
	if externalPkgs := LocalDependencyOptions(moduleRoot); len(externalPkgs) > 0 {
		options = append(options, kcl.WithExternalPkgs(externalPkgs...))
	}

	result, err := kcl.RunFiles([]string{renderFile}, options...)
	if err != nil {
		return "", ExplainKCLError(fmt.Errorf("KCL render failed: %w", err))
	}
	return result.GetRawYamlResult(), nil
}

// Validate compiles factory_seed.k without rendering to check for errors.
func Validate(factoryDir string, seedFile string) error {
	moduleRoot, seedPath, err := resolveKCLFile(factoryDir, seedFile)
	if err != nil {
		return err
	}

	options := []kcl.Option{
		kcl.WithWorkDir(moduleRoot),
		kcl.WithOptions(ConventionOptions(factoryDir)...),
	}
	if externalPkgs := LocalDependencyOptions(moduleRoot); len(externalPkgs) > 0 {
		options = append(options, kcl.WithExternalPkgs(externalPkgs...))
	}

	_, err = kcl.RunFiles([]string{seedPath}, options...)
	return ExplainKCLError(err)
}

// FindModuleRoot returns the nearest ancestor directory containing kcl.mod.
func FindModuleRoot(startDir string) (string, error) {
	absDir, err := filepath.Abs(startDir)
	if err != nil {
		return "", fmt.Errorf("cannot resolve directory %s: %w", startDir, err)
	}

	info, err := os.Stat(absDir)
	if err != nil {
		return "", fmt.Errorf("cannot stat %s: %w", absDir, err)
	}
	if !info.IsDir() {
		absDir = filepath.Dir(absDir)
	}

	for {
		if _, err := os.Stat(filepath.Join(absDir, "kcl.mod")); err == nil {
			return absDir, nil
		}
		parent := filepath.Dir(absDir)
		if parent == absDir {
			return "", fmt.Errorf("kcl.mod not found at or above %s", startDir)
		}
		absDir = parent
	}
}

func resolveKCLFile(factoryDir string, fileName string) (string, string, error) {
	absFactory, err := filepath.Abs(factoryDir)
	if err != nil {
		return "", "", fmt.Errorf("cannot resolve factory dir: %w", err)
	}

	absFile := filepath.Join(absFactory, fileName)
	if _, err := os.Stat(absFile); os.IsNotExist(err) {
		return "", "", fmt.Errorf("%s not found in %s", fileName, absFactory)
	} else if err != nil {
		return "", "", fmt.Errorf("cannot stat %s: %w", absFile, err)
	}

	moduleRoot, err := FindModuleRoot(absFactory)
	if err != nil {
		return "", "", err
	}

	relFile, err := filepath.Rel(moduleRoot, absFile)
	if err != nil {
		return "", "", fmt.Errorf("cannot make %s relative to %s: %w", absFile, moduleRoot, err)
	}
	return moduleRoot, filepath.ToSlash(relFile), nil
}

// LocalDependencyOptions returns KCL -E option strings for local path dependencies,
// including transitive local dependencies. The KCL Go SDK is stricter than the CLI
// for nested packages, so explicit mappings keep Go CLI rendering aligned with
// `kcl run` from the package directory.
func LocalDependencyOptions(moduleRoot string) []string {
	seen := map[string]bool{}
	return localDependencyOptions(moduleRoot, seen)
}

func localDependencyOptions(moduleRoot string, seen map[string]bool) []string {
	modPath := filepath.Join(moduleRoot, "kcl.mod")
	data, err := os.ReadFile(modPath)
	if err != nil {
		return nil
	}

	options := []string{}
	inDependencies := false
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			inDependencies = line == "[dependencies]"
			continue
		}
		if !inDependencies || line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		match := localDependencyRE.FindStringSubmatch(line)
		if len(match) == 3 {
			name := match[1]
			depPath, err := filepath.Abs(filepath.Join(moduleRoot, match[2]))
			if err != nil || seen[name] {
				continue
			}
			seen[name] = true
			options = append(options, name+"="+depPath)
			options = append(options, localDependencyOptions(depPath, seen)...)
			continue
		}

		match = registryDependencyRE.FindStringSubmatch(line)
		if len(match) != 3 {
			continue
		}
		name := match[1]
		version := match[2]
		if seen[name] {
			continue
		}
		if depPath := cachedRegistryDependencyPath(name, version); depPath != "" {
			seen[name] = true
			options = append(options, name+"="+depPath)
		}
	}
	return options
}

func cachedRegistryDependencyPath(name string, version string) string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	depPath := filepath.Join(home, ".kcl", "kpm", name+"_"+version)
	if info, err := os.Stat(depPath); err == nil && info.IsDir() {
		return depPath
	}
	return ""
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

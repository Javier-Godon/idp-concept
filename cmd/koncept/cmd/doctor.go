package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/idp-concept/koncept/internal/config"
	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Check local koncept, KCL, and factory setup",
	Long: `Doctor runs lightweight preflight checks for common adoption issues:
- factory directory exists
- render.k and factory_seed.k exist
- nearest kcl.mod can be found for module resolution
- optional KCL CLI is available for direct troubleshooting
- output and Helm template settings are visible`,
	RunE: runDoctor,
}

func runDoctor(cmd *cobra.Command, args []string) error {
	cfg := config.Load(".")
	failed := false

	fmt.Println("[Doctor] Checking koncept setup...")

	if err := checkFactoryDir(factoryDir); err != nil {
		failed = true
		printError(err.Error())
	} else {
		printSuccess(fmt.Sprintf("Factory directory found: %s", cleanPath(factoryDir)))
	}

	if err := checkFactoryFile(factoryDir, cfg.Spec.Factory.RenderFile); err != nil {
		failed = true
		printError(err.Error())
	} else {
		printSuccess(fmt.Sprintf("Render file found: %s", filepath.Join(cleanPath(factoryDir), cfg.Spec.Factory.RenderFile)))
	}

	if err := checkFactoryFile(factoryDir, cfg.Spec.Factory.SeedFile); err != nil {
		failed = true
		printError(err.Error())
	} else {
		printSuccess(fmt.Sprintf("Seed file found: %s", filepath.Join(cleanPath(factoryDir), cfg.Spec.Factory.SeedFile)))
	}

	if moduleRoot, err := factory.FindModuleRoot(factoryDir); err != nil {
		failed = true
		printError(err.Error())
		fmt.Println("   Hint: run from a KCL package or pass --factory under a directory with an ancestor kcl.mod")
	} else {
		printSuccess(fmt.Sprintf("KCL module root found: %s", moduleRoot))
	}

	if path, err := exec.LookPath("kcl"); err != nil {
		fmt.Println("⚠️  kcl executable not found on PATH. The Go CLI uses the KCL SDK, but installing kcl helps with direct debugging.")
	} else {
		version := kclVersion(path)
		if version != "" {
			printSuccess(fmt.Sprintf("KCL CLI found: %s (%s)", path, version))
		} else {
			printSuccess(fmt.Sprintf("KCL CLI found: %s", path))
		}
	}

	outDir := resolveOutputDir(cfg)
	printInfo(fmt.Sprintf("Default output format: %s", cfg.Spec.DefaultOutput))
	printInfo(fmt.Sprintf("Output directory: %s", outDir))
	if cfg.Spec.Output.HelmTemplatesDir != "" {
		printInfo(fmt.Sprintf("Helm templates directory: %s", cfg.Spec.Output.HelmTemplatesDir))
	}

	if failed {
		return fmt.Errorf("doctor found blocking setup issues")
	}
	printSuccess("Doctor checks passed")
	return nil
}

func checkFactoryDir(dir string) error {
	info, err := os.Stat(dir)
	if err != nil {
		return fmt.Errorf("factory directory not found: %s", dir)
	}
	if !info.IsDir() {
		return fmt.Errorf("factory path is not a directory: %s", dir)
	}
	return nil
}

func checkFactoryFile(dir string, fileName string) error {
	if fileName == "" {
		return fmt.Errorf("factory file name is empty")
	}
	path := filepath.Join(dir, fileName)
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("factory file not found: %s", path)
	}
	if info.IsDir() {
		return fmt.Errorf("factory file path is a directory: %s", path)
	}
	return nil
}

func kclVersion(path string) string {
	cmd := exec.Command(path, "version")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func cleanPath(path string) string {
	cleaned, err := filepath.Abs(path)
	if err != nil {
		return path
	}
	return cleaned
}

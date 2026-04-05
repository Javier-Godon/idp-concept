package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/idp-concept/koncept/internal/output"
	"github.com/spf13/cobra"
)

var goldenCmd = &cobra.Command{
	Use:   "golden [update|check]",
	Short: "Manage golden files for regression testing",
	Long: `Golden files are committed expected-output snapshots used by CI to detect drift.

  koncept golden update   — re-render and overwrite golden/ directory
  koncept golden check    — render and diff against golden/ (exit 1 on drift)`,
	Args:      cobra.ExactArgs(1),
	ValidArgs: []string{"update", "check"},
	RunE:      runGolden,
}

var goldenFormats []string

func runGolden(cmd *cobra.Command, args []string) error {
	action := args[0]

	if !factory.HasRenderK(factoryDir) {
		return fmt.Errorf("render.k not found in %s — run 'koncept init' first", factoryDir)
	}

	goldenDir := filepath.Join(filepath.Dir(factoryDir), "golden")

	if len(goldenFormats) == 0 {
		goldenFormats = []string{"yaml"}
	}

	switch action {
	case "update":
		return goldenUpdate(goldenDir)
	case "check":
		return goldenCheck(goldenDir)
	default:
		return fmt.Errorf("unknown action: %s (use 'update' or 'check')", action)
	}
}

func goldenUpdate(goldenDir string) error {
	for _, format := range goldenFormats {
		kclFormat := format
		if format == "argocd" {
			kclFormat = "yaml"
		}

		fmt.Printf("[golden] Rendering %s...\n", format)
		result, err := factory.Render(factoryDir, kclFormat)
		if err != nil {
			return fmt.Errorf("render %s failed: %w", format, err)
		}

		formatDir := filepath.Join(goldenDir, format)
		outFile := filepath.Join(formatDir, "manifests.yaml")
		if err := output.WriteYAML(result, outFile); err != nil {
			return fmt.Errorf("write golden %s failed: %w", format, err)
		}
		printSuccess(fmt.Sprintf("Golden file updated: %s", outFile))
	}
	return nil
}

func goldenCheck(goldenDir string) error {
	if _, err := os.Stat(goldenDir); os.IsNotExist(err) {
		return fmt.Errorf("golden/ directory not found — run 'koncept golden update' first")
	}

	drift := false
	for _, format := range goldenFormats {
		kclFormat := format
		if format == "argocd" {
			kclFormat = "yaml"
		}

		goldenFile := filepath.Join(goldenDir, format, "manifests.yaml")
		if _, err := os.Stat(goldenFile); os.IsNotExist(err) {
			fmt.Printf("[golden] Skipping %s — no golden file at %s\n", format, goldenFile)
			continue
		}

		fmt.Printf("[golden] Checking %s...\n", format)
		result, err := factory.Render(factoryDir, kclFormat)
		if err != nil {
			return fmt.Errorf("render %s failed: %w", format, err)
		}

		existing, err := os.ReadFile(goldenFile)
		if err != nil {
			return fmt.Errorf("read golden file %s: %w", goldenFile, err)
		}

		if result != string(existing) {
			printError(fmt.Sprintf("Golden file drift: %s", goldenFile))
			drift = true
		} else {
			printSuccess(fmt.Sprintf("Golden file matches: %s", goldenFile))
		}
	}

	if drift {
		return fmt.Errorf("golden file drift detected — run 'koncept golden update' to accept changes")
	}
	printSuccess("All golden files match")
	return nil
}

func init() {
	goldenCmd.Flags().StringSliceVar(&goldenFormats, "formats", []string{"yaml"}, "output formats to generate golden files for")
}

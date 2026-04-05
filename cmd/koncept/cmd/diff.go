package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var diffCmd = &cobra.Command{
	Use:   "diff [format]",
	Short: "Show YAML diff between current render and committed output",
	Long:  `Render the current configuration and diff against the committed output directory.`,
	Args:  cobra.MaximumNArgs(1),
	RunE:  runDiff,
}

func runDiff(cmd *cobra.Command, args []string) error {
	format := "yaml"
	if len(args) > 0 {
		format = args[0]
	}

	if !factory.HasRenderK(factoryDir) {
		return fmt.Errorf("render.k not found in %s", factoryDir)
	}

	fmt.Printf("[Diff] Rendering %s and comparing against output...\n", format)

	kclFormat := format
	if format == "argocd" {
		kclFormat = "yaml"
	}

	current, err := factory.Render(factoryDir, kclFormat)
	if err != nil {
		return fmt.Errorf("render failed: %w", err)
	}

	// Write to temp file
	tmpFile, err := os.CreateTemp("", "koncept-diff-*.yaml")
	if err != nil {
		return err
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(current); err != nil {
		tmpFile.Close()
		return err
	}
	tmpFile.Close()

	// Find existing output file
	outDir := "output"
	if outputDir != "" {
		outDir = outputDir
	}
	existingFile := findExistingOutput(outDir, format)
	if existingFile == "" {
		fmt.Println("No existing output found — showing full render:")
		fmt.Println(current)
		return nil
	}

	// Run diff
	diffCmd := exec.Command("diff", "--color=auto", "-u", existingFile, tmpFile.Name())
	diffCmd.Stdout = os.Stdout
	diffCmd.Stderr = os.Stderr
	err = diffCmd.Run()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			if exitErr.ExitCode() == 1 {
				// diff returns 1 when files differ — not an error
				return nil
			}
		}
		return err
	}

	printSuccess("No differences found")
	return nil
}

func findExistingOutput(outDir string, format string) string {
	candidates := []string{
		fmt.Sprintf("%s/kubernetes_manifests.yaml", outDir),
		fmt.Sprintf("%s/helmfile.yaml", outDir),
		fmt.Sprintf("%s/kusion_spec.yaml", outDir),
		fmt.Sprintf("%s/base/kustomization.yaml", outDir),
	}

	for _, c := range candidates {
		if strings.Contains(c, format) || format == "yaml" || format == "argocd" {
			if _, err := os.Stat(c); err == nil {
				return c
			}
		}
	}

	// Fallback: first yaml file in output dir
	if _, err := os.Stat(candidates[0]); err == nil {
		return candidates[0]
	}
	return ""
}

package cmd

import (
	"fmt"
	"path/filepath"
	"time"

	"github.com/idp-concept/koncept/internal/config"
	"github.com/idp-concept/koncept/internal/factory"
	"github.com/idp-concept/koncept/internal/output"
	"github.com/spf13/cobra"
)

var dryRunCmd = &cobra.Command{
	Use:   "dry-run",
	Short: "Preview merged configuration and orchestration plans without rendering deployable manifests",
	Long: `Dry-run generates a planning document from the factory stack, including merged
configuration values, module dependency edges, Helmfile release projection, and
Crossplane V2 sequencing metadata.`,
	RunE: runDryRun,
}

func runDryRun(cmd *cobra.Command, args []string) error {
	cfg := config.Load(".")
	if !factory.HasRenderK(factoryDir) {
		return fmt.Errorf("render.k not found in %s — run 'koncept init' first", factoryDir)
	}

	fmt.Println("[DryRun] Generating dependency-aware preview plan...")
	start := time.Now()
	result, err := factory.Render(factoryDir, "dry-run")
	recorder().Record("dry-run", "", time.Since(start), err)
	if err != nil {
		printError(fmt.Sprintf("Dry-run failed: %v", err))
		return err
	}

	outDir := resolveOutputDir(cfg)
	outFile := filepath.Join(outDir, "dry_run_plan.yaml")
	if err := output.WriteYAML(result, outFile); err != nil {
		return err
	}

	printSuccess(fmt.Sprintf("Dry-run plan written to %s", outFile))
	return nil
}


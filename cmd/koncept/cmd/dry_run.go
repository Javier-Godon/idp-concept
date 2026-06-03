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

	// Display resource footprint summary if available
	displayDryRunSummary(result)

	return nil

func displayDryRunSummary(plan interface{}) {
	planMap, ok := plan.(map[string]interface{})
	if !ok {
		return
	}

	spec, ok := planMap["spec"].(map[string]interface{})
	if !ok {
		return
	}

	// Print footprint summary
	fmt.Println()
	printInfo("[Observability] Resource Footprint Summary:")

	if footprint, ok := spec["resourceFootprint"].(map[string]interface{}); ok {
		if deployments, ok := footprint["deploymentCount"].(float64); ok && deployments > 0 {
			fmt.Printf("  - Deployments: %d\n", int(deployments))
		}
		if statefulsets, ok := footprint["statefulsetCount"].(float64); ok && statefulsets > 0 {
			fmt.Printf("  - StatefulSets: %d\n", int(statefulsets))
		}
		if daemonsets, ok := footprint["daemonsetCount"].(float64); ok && daemonsets > 0 {
			fmt.Printf("  - DaemonSets: %d\n", int(daemonsets))
		}
		if pvcs, ok := footprint["persistentVolumeClaimCount"].(float64); ok && pvcs > 0 {
			fmt.Printf("  - PersistentVolumeClaims: %d\n", int(pvcs))
		}
		if manifests, ok := footprint["manifestCount"].(float64); ok {
			fmt.Printf("  - Total manifests to deploy: %d\n", int(manifests))
		}

		if storage, ok := footprint["storageInfo"].(map[string]interface{}); ok {
			if warning, ok := storage["warning"].(string); ok && warning != "" {
				fmt.Printf("  [warn] %s\n", warning)
			}
		}
	}

	// Print orchestration summary
	fmt.Println()
	printInfo("[Orchestration] Deployment Strategy:")

	if outputs, ok := spec["outputs"].(map[string]interface{}); ok {
		if helmfile, ok := outputs["helmfile"].(map[string]interface{}); ok {
			if count, ok := helmfile["releaseCount"].(float64); ok {
				fmt.Printf("  - Helmfile releases: %d\n", int(count))
			}
		}
		if crossplane, ok := outputs["crossplane"].(map[string]interface{}); ok {
			if metadata, ok := crossplane["metadata"].(map[string]interface{}); ok {
				if resourceCount, ok := metadata["resourceCount"].(float64); ok {
					fmt.Printf("  - Crossplane resources: %d\n", int(resourceCount))
				}
			}
		}
	}
}


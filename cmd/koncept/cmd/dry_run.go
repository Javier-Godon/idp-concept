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
}

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

		// Display resource requests
		if cpuReq, ok := footprint["cpuRequest"].(map[string]interface{}); ok {
			if cpu, ok := cpuReq["millis"].(float64); ok && cpu > 0 {
				fmt.Printf("  - Estimated CPU request: %dm (%.1f cores)\n", int(cpu), cpu/1000)
				if estNodes, ok := cpuReq["estimatedNodes"].(float64); ok {
					fmt.Printf("    Estimated nodes (small 2-core): %.1f\n", estNodes)
				}
			}
		}
		if memReq, ok := footprint["memoryRequest"].(map[string]interface{}); ok {
			if mem, ok := memReq["mb"].(float64); ok && mem > 0 {
				fmt.Printf("  - Estimated memory request: %dMi (%.1f Gi)\n", int(mem), mem/1024)
			}
		}

		// Storage information
		if storage, ok := footprint["storageInfo"].(map[string]interface{}); ok {
			if storageGb, ok := storage["estimatedGb"].(float64); ok && storageGb > 0 {
				fmt.Printf("  - Estimated persistent storage: %dGi\n", int(storageGb))
			}
			if warning, ok := storage["warning"].(string); ok && warning != "" {
				fmt.Printf("  [warn] %s\n", warning)
			}
		}

		// Show warnings if any
		if warnings, ok := footprint["warnings"].([]interface{}); ok && len(warnings) > 0 {
			fmt.Println("  [⚠️  Resource Warnings]")
			for _, w := range warnings {
				if wStr, ok := w.(string); ok {
					fmt.Printf("    - %s\n", wStr)
				}
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

	fmt.Println()
	printInfo("[Planning] Next Steps:")
	fmt.Println("  1. Review merged configurations in dry_run_plan.yaml")
	fmt.Println("  2. Verify dependency orchestration and resource footprint")
	fmt.Println("  3. Run 'koncept render' with desired format (yaml|helmfile|crossplane|argocd)")
}


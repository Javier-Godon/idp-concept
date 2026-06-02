package cmd

import (
	"fmt"
	"os"
	"time"

	xptest "github.com/idp-concept/koncept/internal/crossplane"
	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var (
	crossplaneTestSkipRender        bool
	crossplaneTestRequireCLI        bool
	crossplaneTestKeepFiles         bool
	crossplaneRuntimeMode           string
	crossplaneRuntimeProfile        string
	crossplaneRuntimeContext        string
	crossplaneRuntimeTimeout        string
	crossplaneRuntimePrereqs        bool
	crossplaneRuntimeCleanup        bool
	crossplaneRuntimeCleanupPrereqs bool
)

var crossplaneCmd = &cobra.Command{
	Use:   "crossplane",
	Short: "Crossplane-focused validation and lifecycle helpers",
	Long: `Crossplane commands help validate generated Crossplane v2 output and
maintain deterministic, reviewable platform API artifacts.`,
}

var crossplaneTestCmd = &cobra.Command{
	Use:   "test",
	Short: "Validate Crossplane output contracts and optionally run local composition render",
	Long: `crossplane test renders Crossplane output from the current factory and validates:

  - required output sections (xrd, composition, xr, prerequisites)
  - pipeline shape and required steps
  - pinned Provider/Function packages (no latest)
  - optional local crossplane render with function results

By default it attempts local crossplane render only if the crossplane CLI binary
is available in PATH. Use --require-cli to fail when it is missing.`,
	RunE: runCrossplaneTest,
}

func runCrossplaneTest(cmd *cobra.Command, args []string) error {
	if !factory.HasRenderK(factoryDir) {
		return fmt.Errorf("render.k not found in %s — run from a factory directory or pass --factory", factoryDir)
	}

	printInfo(fmt.Sprintf("crossplane test: rendering from %s", factoryDir))
	start := time.Now()
	rendered, err := factory.Render(factoryDir, "crossplane")
	if err != nil {
		recorder().Record("crossplane-test", "render", time.Since(start), err)
		return err
	}

	report, err := xptest.ValidateRenderedOutput(rendered, !crossplaneTestSkipRender, crossplaneTestRequireCLI)
	recorder().Record("crossplane-test", "validate", time.Since(start), err)
	if err != nil {
		return err
	}

	printSuccess("crossplane test: static contract checks passed")
	fmt.Printf("  providers pinned: %d\n", len(report.ProviderPackages))
	fmt.Printf("  functions pinned: %d\n", len(report.FunctionPackages))

	for _, warning := range report.Warnings {
		fmt.Printf("  [warn] %s\n", warning)
	}

	if report.CrossplaneRenderRan {
		printSuccess("crossplane test: local crossplane render passed")
		if report.CrossplaneRenderOut != "" {
			fmt.Println(report.CrossplaneRenderOut)
		}
	} else if !crossplaneTestSkipRender {
		printInfo("crossplane test: local crossplane render skipped")
	}

	runtimeOpts, err := xptest.ResolveRuntimeOptions(crossplaneRuntimeProfile, xptest.RuntimeOptions{
		Mode:                 crossplaneRuntimeMode,
		KubeContext:          crossplaneRuntimeContext,
		Timeout:              crossplaneRuntimeTimeout,
		IncludePrerequisites: crossplaneRuntimePrereqs,
		Cleanup:              crossplaneRuntimeCleanup,
		CleanupPrerequisites: crossplaneRuntimeCleanupPrereqs,
	})
	if err != nil {
		return err
	}
	if runtimeOpts.Mode != xptest.RuntimeModeNone {
		if crossplaneRuntimeProfile != xptest.RuntimeProfileNone {
			printInfo(fmt.Sprintf("crossplane test: using runtime profile %s", crossplaneRuntimeProfile))
		}
		printInfo(fmt.Sprintf("crossplane test: running runtime mode %s", runtimeOpts.Mode))
		err = xptest.RunRuntimeChecks(report.ArtifactsDir, runtimeOpts)
		recorder().Record("crossplane-test", "runtime", time.Since(start), err)
		if err != nil {
			return err
		}
		printSuccess("crossplane test: runtime checks passed")
	}

	if crossplaneTestKeepFiles {
		printInfo(fmt.Sprintf("crossplane test artifacts kept at %s", report.ArtifactsDir))
	} else {
		_ = os.RemoveAll(report.ArtifactsDir)
	}

	return nil
}

func init() {
	crossplaneTestCmd.Flags().BoolVar(&crossplaneTestSkipRender, "skip-render", false, "skip optional local crossplane render execution")
	crossplaneTestCmd.Flags().BoolVar(&crossplaneTestRequireCLI, "require-cli", false, "fail when crossplane CLI is not installed")
	crossplaneTestCmd.Flags().BoolVar(&crossplaneTestKeepFiles, "keep-artifacts", false, "keep generated temporary crossplane artifacts for inspection")
	crossplaneTestCmd.Flags().StringVar(&crossplaneRuntimeProfile, "runtime-profile", xptest.RuntimeProfileNone, "runtime profile preset: none|smoke|lifecycle|catalog|api-lifecycle")
	crossplaneTestCmd.Flags().StringVar(&crossplaneRuntimeMode, "runtime-mode", xptest.RuntimeModeNone, "optional kubectl runtime mode: none|server-dry-run|apply-delete")
	crossplaneTestCmd.Flags().StringVar(&crossplaneRuntimeContext, "runtime-context", "", "optional kube context for runtime mode")
	crossplaneTestCmd.Flags().StringVar(&crossplaneRuntimeTimeout, "runtime-timeout", "120s", "wait timeout for runtime apply-delete mode")
	crossplaneTestCmd.Flags().BoolVar(&crossplaneRuntimePrereqs, "runtime-include-prerequisites", false, "include prerequisites/infrastructure.yaml in runtime checks")
	crossplaneTestCmd.Flags().BoolVar(&crossplaneRuntimeCleanup, "runtime-cleanup", true, "delete XR/composition/XRD after runtime apply-delete checks")
	crossplaneTestCmd.Flags().BoolVar(&crossplaneRuntimeCleanupPrereqs, "runtime-cleanup-prerequisites", false, "also delete prerequisites during runtime cleanup (disabled by default for safety)")

	crossplaneCmd.AddCommand(crossplaneTestCmd)
}

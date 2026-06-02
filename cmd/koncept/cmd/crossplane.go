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
	crossplaneTestSkipRender bool
	crossplaneTestRequireCLI bool
	crossplaneTestKeepFiles  bool
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

	if crossplaneTestKeepFiles {
		printInfo(fmt.Sprintf("crossplane test artifacts kept at %s", report.ArtifactsDir))
	} else {
		_ = os.RemoveAll(report.ArtifactsDir)
	}

	return nil
}

func init() {
	crossplaneTestCmd.Flags().BoolVar(&crossplaneTestSkipRender, "skip-render", false, "skip optional local `crossplane render` execution")
	crossplaneTestCmd.Flags().BoolVar(&crossplaneTestRequireCLI, "require-cli", false, "fail when crossplane CLI is not installed")
	crossplaneTestCmd.Flags().BoolVar(&crossplaneTestKeepFiles, "keep-artifacts", false, "keep generated temporary crossplane artifacts for inspection")

	crossplaneCmd.AddCommand(crossplaneTestCmd)
}

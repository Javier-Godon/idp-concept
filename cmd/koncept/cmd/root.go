package cmd

import (
	"fmt"

	"github.com/idp-concept/koncept/internal/metrics"
	"github.com/spf13/cobra"
)

var (
	version       = "dev"
	buildTime     = "unknown"
	factoryDir    string
	outputDir     string
	metricsEnable bool
	metricsFile   string
)

// recorder returns a metrics recorder honoring the --metrics flag and the
// KONCEPT_METRICS env var. Telemetry is local-only and opt-in.
func recorder() *metrics.Recorder {
	enabled := metricsEnable || metrics.EnabledFromEnv()
	return metrics.NewRecorder(enabled, metricsFile, version)
}

var rootCmd = &cobra.Command{
	Use:   "koncept",
	Short: "IDP CLI — render K8s manifests from KCL configurations",
	Long: `koncept is the CLI for idp-concept, an Internal Developer Platform
that uses KCL as the single source of truth to generate Kubernetes
deployment manifests in multiple output formats.`,
	Version: version,
}

// SetVersionTemplate wires build metadata into the --version output.
func init() {
	rootCmd.SetVersionTemplate("koncept {{.Version}} (built " + buildTime + ")\n")
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	rootCmd.PersistentFlags().StringVar(&factoryDir, "factory", "factory", "factory directory path")
	rootCmd.PersistentFlags().StringVar(&outputDir, "output", "", "output directory path")
	rootCmd.PersistentFlags().BoolVar(&metricsEnable, "metrics", false, "record opt-in local telemetry (also enabled by KONCEPT_METRICS=1)")
	rootCmd.PersistentFlags().StringVar(&metricsFile, "metrics-file", "", "telemetry JSONL path (default: user config dir or KONCEPT_METRICS_FILE)")

	rootCmd.AddCommand(renderCmd)
	rootCmd.AddCommand(dryRunCmd)
	rootCmd.AddCommand(validateCmd)
	rootCmd.AddCommand(initCmd)
	rootCmd.AddCommand(testCmd)
	rootCmd.AddCommand(fmtCmd)
	rootCmd.AddCommand(diffCmd)
	rootCmd.AddCommand(lintCmd)
	rootCmd.AddCommand(depsCmd)
	rootCmd.AddCommand(publishCmd)
	rootCmd.AddCommand(goldenCmd)
	rootCmd.AddCommand(doctorCmd)
	rootCmd.AddCommand(completionCmd)
	rootCmd.AddCommand(policyCmd)
	rootCmd.AddCommand(changelogCmd)
	rootCmd.AddCommand(crossplaneCmd)
	rootCmd.AddCommand(metricsCmd)
}

func printSuccess(msg string) {
	fmt.Printf("✅ %s\n", msg)
}

func printError(msg string) {
	fmt.Printf("❌ %s\n", msg)
}

func printInfo(msg string) {
	fmt.Printf("[%s]\n", msg)
}

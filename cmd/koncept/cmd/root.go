package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var (
	version    = "dev"
	factoryDir string
	outputDir  string
)

var rootCmd = &cobra.Command{
	Use:   "koncept",
	Short: "IDP CLI — render K8s manifests from KCL configurations",
	Long: `koncept is the CLI for idp-concept, an Internal Developer Platform
that uses KCL as the single source of truth to generate Kubernetes
deployment manifests in multiple output formats.`,
	Version: version,
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	rootCmd.PersistentFlags().StringVar(&factoryDir, "factory", "factory", "factory directory path")
	rootCmd.PersistentFlags().StringVar(&outputDir, "output", "", "output directory path")

	rootCmd.AddCommand(renderCmd)
	rootCmd.AddCommand(validateCmd)
	rootCmd.AddCommand(initCmd)
	rootCmd.AddCommand(testCmd)
	rootCmd.AddCommand(fmtCmd)
	rootCmd.AddCommand(diffCmd)
	rootCmd.AddCommand(lintCmd)
	rootCmd.AddCommand(depsCmd)
	rootCmd.AddCommand(publishCmd)
	rootCmd.AddCommand(goldenCmd)
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

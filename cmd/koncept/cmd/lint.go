package cmd

import (
	"fmt"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var lintCmd = &cobra.Command{
	Use:   "lint [paths...]",
	Short: "Lint KCL files for common issues",
	Long:  `Lint all KCL files in the given paths (defaults to current directory).`,
	RunE:  runLint,
}

func runLint(cmd *cobra.Command, args []string) error {
	paths := args
	if len(paths) == 0 {
		paths = []string{"."}
	}

	fmt.Printf("[Lint] Checking KCL files...\n")
	results, err := factory.Lint(paths)
	if err != nil {
		printError(fmt.Sprintf("Lint failed: %v", err))
		return err
	}

	if len(results) == 0 {
		printSuccess("No lint issues found")
		return nil
	}

	for _, r := range results {
		fmt.Printf("  ⚠️  %s\n", r)
	}
	return fmt.Errorf("%d lint issue(s) found", len(results))
}

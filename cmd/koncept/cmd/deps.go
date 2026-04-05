package cmd

import (
	"fmt"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var depsCmd = &cobra.Command{
	Use:   "deps [path]",
	Short: "Show dependency files for a KCL package",
	Long:  `List all dependency files from the given path (defaults to current directory).`,
	Args:  cobra.MaximumNArgs(1),
	RunE:  runDeps,
}

func runDeps(cmd *cobra.Command, args []string) error {
	dir := "."
	if len(args) > 0 {
		dir = args[0]
	}

	fmt.Printf("[Deps] Listing dependencies for %s...\n", dir)
	deps, err := factory.ListDeps(dir)
	if err != nil {
		printError(fmt.Sprintf("Failed to list dependencies: %v", err))
		return err
	}

	if len(deps) == 0 {
		fmt.Println("  No dependencies found")
		return nil
	}

	for _, d := range deps {
		fmt.Printf("  %s\n", d)
	}
	fmt.Printf("\n  Total: %d files\n", len(deps))
	return nil
}

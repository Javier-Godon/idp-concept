package cmd

import (
	"fmt"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var fmtCmd = &cobra.Command{
	Use:   "fmt [path]",
	Short: "Format KCL files",
	Long:  `Format all KCL files in the given path (defaults to current directory).`,
	Args:  cobra.MaximumNArgs(1),
	RunE:  runFmt,
}

func runFmt(cmd *cobra.Command, args []string) error {
	path := "."
	if len(args) > 0 {
		path = args[0]
	}

	fmt.Printf("[Fmt] Formatting KCL files in %s...\n", path)
	changed, err := factory.Format(path)
	if err != nil {
		printError(fmt.Sprintf("Format failed: %v", err))
		return err
	}

	if len(changed) == 0 {
		printSuccess("All files already formatted")
	} else {
		for _, f := range changed {
			fmt.Printf("  formatted: %s\n", f)
		}
		printSuccess(fmt.Sprintf("%d file(s) formatted", len(changed)))
	}
	return nil
}

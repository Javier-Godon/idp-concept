package cmd

import (
	"fmt"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var testCmd = &cobra.Command{
	Use:   "test [path]",
	Short: "Run KCL tests",
	Long:  `Run KCL unit tests in the given path (defaults to framework/).`,
	Args:  cobra.MaximumNArgs(1),
	RunE:  runTest,
}

func runTest(cmd *cobra.Command, args []string) error {
	testDir := "framework"
	if len(args) > 0 {
		testDir = args[0]
	}

	fmt.Printf("[Test] Running KCL tests in %s...\n", testDir)
	output, failed, err := factory.RunTest(testDir)
	if err != nil {
		printError(fmt.Sprintf("Test execution failed: %v", err))
		return err
	}

	fmt.Print(output)

	if failed > 0 {
		printError(fmt.Sprintf("%d test(s) failed", failed))
		return fmt.Errorf("%d test(s) failed", failed)
	}

	printSuccess("All tests passed")
	return nil
}

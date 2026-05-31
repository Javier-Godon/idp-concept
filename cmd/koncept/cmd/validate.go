package cmd

import (
	"fmt"
	"time"

	"github.com/idp-concept/koncept/internal/config"
	"github.com/idp-concept/koncept/internal/factory"
	"github.com/spf13/cobra"
)

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate KCL factory configurations without rendering",
	Long:  `Validate compiles the factory seed to check for configuration errors.`,
	RunE:  runValidate,
}

func runValidate(cmd *cobra.Command, args []string) error {
	cfg := config.Load(".")

	fmt.Println("[Validate] Checking factory configuration...")

	start := time.Now()
	seedFile := cfg.Spec.Factory.SeedFile
	err := factory.Validate(factoryDir, seedFile)
	recorder().Record("validate", "", time.Since(start), err)
	if err != nil {
		printError(fmt.Sprintf("Validation failed:\n%v", err))
		return err
	}

	printSuccess("Configuration is valid")
	return nil
}

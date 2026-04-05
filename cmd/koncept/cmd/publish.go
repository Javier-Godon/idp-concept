package cmd

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var publishCmd = &cobra.Command{
	Use:   "publish <module_path>",
	Short: "Publish a KCL module as OCI artifact",
	Long:  `Push a KCL module to an OCI registry using 'kcl mod push'.`,
	Args:  cobra.ExactArgs(1),
	RunE:  runPublish,
}

var publishVersion string

func init() {
	publishCmd.Flags().StringVar(&publishVersion, "version", "", "version tag for the OCI artifact (required)")
	publishCmd.MarkFlagRequired("version")
}

func runPublish(cmd *cobra.Command, args []string) error {
	modulePath := args[0]

	fmt.Printf("[Publish] Pushing %s as OCI artifact v%s...\n", modulePath, publishVersion)

	// Delegate to kcl CLI for OCI push
	kclCmd := exec.Command("kcl", "mod", "push",
		fmt.Sprintf("oci://%s:%s", modulePath, publishVersion))
	kclCmd.Dir = modulePath
	kclCmd.Stdout = os.Stdout
	kclCmd.Stderr = os.Stderr

	if err := kclCmd.Run(); err != nil {
		printError(fmt.Sprintf("Publish failed: %v", err))
		return err
	}

	printSuccess(fmt.Sprintf("Published %s:%s", modulePath, publishVersion))
	return nil
}

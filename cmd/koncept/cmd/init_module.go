package cmd

import (
	"fmt"
	"os"
	"strings"

	"github.com/idp-concept/koncept/internal/scaffold"
	"github.com/spf13/cobra"
)

var (
	initModuleProject string
	initModuleImage   string
	initModuleVersion string
	initModulePort    int
	initModuleStorage string
)

var initModuleCmd = &cobra.Command{
	Use:   "module <type> <name>",
	Short: "Scaffold a module definition and print its stack wiring",
	Long: fmt.Sprintf(`module generates a module definition file under
modules/<area>/<name>/<name>_module_def.k in an existing project and prints a
ready-to-paste stack wiring snippet.

Supported types: %s

Examples:
  koncept init module webapp orders-api
  koncept init module postgres orders-db
  koncept init module redis orders-cache

The project is auto-detected from the current directory (the nearest kcl.mod
that depends on the framework). Use --project to target another project root.`,
		strings.Join(scaffold.SupportedModuleTypes(), ", ")),
	Args: cobra.ExactArgs(2),
	RunE: runInitModule,
}

func runInitModule(cmd *cobra.Command, args []string) error {
	moduleType, moduleName := args[0], args[1]

	start := initModuleProject
	if start == "" {
		cwd, err := os.Getwd()
		if err != nil {
			return err
		}
		start = cwd
	}

	projectRoot, slug, err := scaffold.DetectProjectRoot(start)
	if err != nil {
		return err
	}

	spec, err := scaffold.NewModuleSpec(moduleType, moduleName, slug)
	if err != nil {
		return err
	}
	if initModuleImage != "" {
		spec.Image = initModuleImage
	}
	if initModuleVersion != "" {
		spec.Version = initModuleVersion
	}
	if initModulePort != 0 {
		spec.Port = initModulePort
	}
	if initModuleStorage != "" {
		spec.StorageSize = initModuleStorage
	}

	printInfo(fmt.Sprintf("init module: %s %q in project %s (%s)", moduleType, moduleName, slug, projectRoot))
	createdPath, wiring, err := scaffold.GenerateModule(spec, projectRoot)
	if err != nil {
		return err
	}
	printSuccess(fmt.Sprintf("Created %s", createdPath))

	fmt.Println()
	fmt.Println("Wire it into your stack (e.g. stacks/<project>_stack.k):")
	fmt.Println()
	for _, line := range strings.Split(strings.TrimRight(wiring, "\n"), "\n") {
		fmt.Printf("    %s\n", line)
	}
	fmt.Println()
	fmt.Println("Then re-render and validate:")
	fmt.Println("  koncept validate")
	fmt.Println("  koncept render argocd")
	fmt.Println("  koncept policy check")
	return nil
}

func init() {
	initModuleCmd.Flags().StringVar(&initModuleProject, "project", "", "project root directory (default: auto-detect from cwd)")
	initModuleCmd.Flags().StringVar(&initModuleImage, "image", "", "container image (webapp/database)")
	initModuleCmd.Flags().StringVar(&initModuleVersion, "version", "", "image/operator version tag")
	initModuleCmd.Flags().IntVar(&initModulePort, "port", 0, "service/container port (default 8080)")
	initModuleCmd.Flags().StringVar(&initModuleStorage, "storage", "", "persistent volume size for stateful modules (default 1Gi)")
	initCmd.AddCommand(initModuleCmd)
}

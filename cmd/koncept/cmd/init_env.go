package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/idp-concept/koncept/internal/scaffold"
	"github.com/spf13/cobra"
)

var (
	initEnvProject      string
	initEnvNamespace    string
	initEnvStorageClass string
)

var initEnvCmd = &cobra.Command{
	Use:   "env <name>",
	Short: "Scaffold a new environment (profile + site + pre-release factory)",
	Long: `env adds a new environment to an existing project by generating its
profile, site, and pre-release factory, mirroring the development environment
created by 'koncept init project'.

Well-known names get sensible defaults: dev|development, stg|staging, prod|production.
Any other name is slugified and used directly.

Examples:
  koncept init env staging
  koncept init env prod
  koncept init env qa --namespace acme-qa-apps

The project is auto-detected from the current directory (the nearest kcl.mod
that depends on the framework). Use --project to target another project root.`,
	Args: cobra.ExactArgs(1),
	RunE: runInitEnv,
}

func runInitEnv(cmd *cobra.Command, args []string) error {
	envName := args[0]

	start := initEnvProject
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

	spec := scaffold.NewEnvSpec(envName, slug)
	if initEnvNamespace != "" {
		spec.AppsNamespace = initEnvNamespace
	}
	if initEnvStorageClass != "" {
		spec.StorageClass = initEnvStorageClass
	}

	printInfo(fmt.Sprintf("init env: %q in project %s (%s)", spec.Name, slug, projectRoot))
	created, err := scaffold.GenerateEnv(spec, projectRoot)
	if err != nil {
		return err
	}
	for _, p := range created {
		rel, relErr := filepath.Rel(projectRoot, p)
		if relErr != nil {
			rel = p
		}
		printSuccess(fmt.Sprintf("Created %s", rel))
	}

	factoryRel := filepath.ToSlash(filepath.Join("pre_releases", "manifests", spec.Short, "factory"))
	fmt.Println()
	fmt.Println("Render and validate the new environment:")
	fmt.Printf("  koncept validate --factory %s\n", factoryRel)
	fmt.Printf("  koncept render argocd --factory %s\n", factoryRel)
	fmt.Println("  koncept policy check")
	return nil
}

func init() {
	initEnvCmd.Flags().StringVar(&initEnvProject, "project", "", "project root directory (default: auto-detect from cwd)")
	initEnvCmd.Flags().StringVar(&initEnvNamespace, "namespace", "", "apps namespace for the environment (default <project>-apps)")
	initEnvCmd.Flags().StringVar(&initEnvStorageClass, "storage-class", "", "storage class for the environment site (default local-path)")
	initCmd.AddCommand(initEnvCmd)
}

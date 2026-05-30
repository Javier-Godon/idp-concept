package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/idp-concept/koncept/internal/scaffold"
	"github.com/spf13/cobra"
)

var (
	initReleaseProject      string
	initReleaseStorageClass string
)

var initReleaseCmd = &cobra.Command{
	Use:   "release <version>",
	Short: "Scaffold an immutable versioned release (versioned stack + production site + release factory)",
	Long: `release adds an immutable, version-pinned release to an existing project.
It generates a versioned stack, a production site (kept if it already exists),
and a release factory under releases/<version>_production/factory.

The version may be given as 1.0.0 or v1.0.0; it is normalised to a package-safe
form such as v1_0_0.

Examples:
  koncept init release 1.0.0
  koncept init release v2.1.0 --storage-class rook-ceph-block

The project is auto-detected from the current directory (the nearest kcl.mod
that depends on the framework). Use --project to target another project root.`,
	Args: cobra.ExactArgs(1),
	RunE: runInitRelease,
}

func runInitRelease(cmd *cobra.Command, args []string) error {
	version := args[0]

	start := initReleaseProject
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

	spec := scaffold.NewReleaseSpec(version, slug)
	if initReleaseStorageClass != "" {
		spec.StorageClass = initReleaseStorageClass
	}

	printInfo(fmt.Sprintf("init release: %s in project %s (%s)", spec.VersionSlug, slug, projectRoot))
	created, err := scaffold.GenerateRelease(spec, projectRoot)
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

	factoryRel := filepath.ToSlash(filepath.Join("releases", spec.VersionSlug+"_production", "factory"))
	fmt.Println()
	fmt.Println("Render and validate the new release:")
	fmt.Printf("  koncept validate --factory %s\n", factoryRel)
	fmt.Printf("  koncept render argocd --factory %s\n", factoryRel)
	fmt.Println("  koncept policy check")
	return nil
}

func init() {
	initReleaseCmd.Flags().StringVar(&initReleaseProject, "project", "", "project root directory (default: auto-detect from cwd)")
	initReleaseCmd.Flags().StringVar(&initReleaseStorageClass, "storage-class", "", "production storage class (default local-path)")
	initCmd.AddCommand(initReleaseCmd)
}

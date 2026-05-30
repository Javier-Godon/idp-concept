package cmd

import (
	"fmt"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/idp-concept/koncept/internal/scaffold"
	"github.com/spf13/cobra"
)

var (
	initProjectDest          string
	initProjectFrameworkPath string
	initProjectGitRepo       string
	initProjectImage         string
	initProjectVersion       string
	initProjectPort          int
	initProjectOwner         string
	initProjectValidate      bool
)

var initProjectCmd = &cobra.Command{
	Use:   "project <name>",
	Short: "Scaffold a complete, validating webapp project skeleton",
	Long: `project generates a full golden-path project under <dest>/<slug>:

  kernel/ core_sources/ modules/ stacks/ tenants/ sites/ pre_releases/
  + a dev factory (render.k + factory_seed.k)

The generated project renders Tier-1 output out of the box:

  koncept render argocd --factory <dest>/<slug>/pre_releases/manifests/dev/factory`,
	Args: cobra.ExactArgs(1),
	RunE: runInitProject,
}

func runInitProject(cmd *cobra.Command, args []string) error {
	spec := scaffold.NewProjectSpec(args[0])
	if initProjectFrameworkPath != "" {
		spec.FrameworkPath = initProjectFrameworkPath
	}
	if initProjectGitRepo != "" {
		spec.GitRepoURL = initProjectGitRepo
	}
	if initProjectImage != "" {
		spec.Image = initProjectImage
	}
	if initProjectVersion != "" {
		spec.Version = initProjectVersion
	}
	if initProjectPort != 0 {
		spec.Port = initProjectPort
	}
	if initProjectOwner != "" {
		spec.BackstageOwner = initProjectOwner
	}

	fmt.Printf("[init project] Scaffolding %q (slug: %s) under %s/\n", spec.DisplayName, spec.Slug, initProjectDest)
	created, err := scaffold.Generate(spec, initProjectDest)
	if err != nil {
		return err
	}
	for _, f := range created {
		fmt.Printf("  + %s\n", f)
	}
	printSuccess(fmt.Sprintf("Created %d files", len(created)))

	factoryPath := fmt.Sprintf("%s/%s/pre_releases/manifests/dev/factory", initProjectDest, spec.Slug)
	if initProjectValidate {
		fmt.Println()
		printInfo("Validating generated project (kcl compile)")
		if err := factory.Validate(factoryPath, "factory_seed.k"); err != nil {
			return fmt.Errorf("generated project failed validation: %w", err)
		}
		printSuccess("Generated project validates")
	}

	fmt.Println()
	fmt.Println("Next steps:")
	fmt.Printf("  koncept validate --factory %s\n", factoryPath)
	fmt.Printf("  koncept render argocd --factory %s\n", factoryPath)
	fmt.Printf("  koncept policy check --factory %s\n", factoryPath)
	return nil
}

func init() {
	initProjectCmd.Flags().StringVar(&initProjectDest, "dest", "projects", "destination root directory for the new project")
	initProjectCmd.Flags().StringVar(&initProjectFrameworkPath, "framework-path", "../../framework", "kcl.mod path to the framework package, relative to the project root")
	initProjectCmd.Flags().StringVar(&initProjectGitRepo, "git-repo", "", "git repository URL for the project")
	initProjectCmd.Flags().StringVar(&initProjectImage, "image", "", "application container image (without tag)")
	initProjectCmd.Flags().StringVar(&initProjectVersion, "version", "", "application image version tag")
	initProjectCmd.Flags().IntVar(&initProjectPort, "port", 0, "application container/service port (default 8080)")
	initProjectCmd.Flags().StringVar(&initProjectOwner, "owner", "", "ownership/Backstage owner value")
	initProjectCmd.Flags().BoolVar(&initProjectValidate, "validate", true, "validate the generated project with the KCL compiler")
}

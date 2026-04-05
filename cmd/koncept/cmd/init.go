package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Scaffold a new factory directory with render.k + factory_seed.k",
	RunE:  runInit,
}

const factorySeedTemplate = `"""
Factory seed — fills the render.k contract.
Edit the imports and variables below for your environment.

Contract exports: _stack, _project_name, _git_repo_url, _manifest_path
"""
import framework.models.manifests.renderstack
# TODO: import your configurations module
# import <project>.pre_releases.configurations_dev as config

# TODO: set _base_stack from your configurations
# _base_stack = config._stack

# Full stack for rendering (standardized contract variable)
# _stack = renderstack.RenderStack {
#     instanceConfigurations = _base_stack.instanceConfigurations
#     k8snamespaces = _base_stack.k8snamespaces
#     components = _base_stack.components
#     accessories = _base_stack.accessories
# }

# Standardized contract variables for render.k
# _project_name = config._project.instance.name
# _git_repo_url = config._pre_release_configurations.gitRepoUrl
# _manifest_path = "projects/<project>/pre_releases/manifests/<env>/output"
`

func runInit(cmd *cobra.Command, args []string) error {
	targetDir := factoryDir

	renderPath := filepath.Join(targetDir, "render.k")
	if _, err := os.Stat(renderPath); err == nil {
		return fmt.Errorf("factory already exists at %s/render.k", targetDir)
	}

	fmt.Printf("[Init] Scaffolding factory at %s/\n", targetDir)
	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return fmt.Errorf("cannot create directory: %w", err)
	}

	// Try to copy render.k from framework
	frameworkRender := findFrameworkRender()
	if frameworkRender != "" {
		data, err := os.ReadFile(frameworkRender)
		if err == nil {
			if err := os.WriteFile(renderPath, data, 0o644); err != nil {
				return err
			}
			printSuccess("render.k copied from framework")
		}
	} else {
		fmt.Println("  ⚠️  render.k not found in framework — create manually")
	}

	// Write factory_seed.k template
	seedPath := filepath.Join(targetDir, "factory_seed.k")
	if err := os.WriteFile(seedPath, []byte(factorySeedTemplate), 0o644); err != nil {
		return err
	}
	printSuccess("factory_seed.k template created — edit with your project imports")

	fmt.Println()
	fmt.Println("Next steps:")
	fmt.Printf("  1. Edit %s/factory_seed.k with your project imports\n", targetDir)
	fmt.Printf("  2. Run: koncept validate --factory %s\n", targetDir)
	fmt.Printf("  3. Run: koncept render argocd --factory %s\n", targetDir)
	return nil
}

// findFrameworkRender searches for the framework render.k up the directory tree.
func findFrameworkRender() string {
	candidates := []string{
		"framework/factory/render.k",
		"../../framework/factory/render.k",
		"../../../framework/factory/render.k",
	}

	cwd, _ := os.Getwd()
	for _, c := range candidates {
		path := filepath.Join(cwd, c)
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}

	// Also try searching based on koncept.yaml frameworkPath
	cfgPath := filepath.Join(cwd, "koncept.yaml")
	if _, err := os.Stat(cfgPath); err == nil {
		data, err := os.ReadFile(cfgPath)
		if err == nil {
			content := string(data)
			// Simple parse for frameworkPath
			for _, line := range strings.Split(content, "\n") {
				line = strings.TrimSpace(line)
				if strings.HasPrefix(line, "frameworkPath:") {
					fwPath := strings.TrimSpace(strings.TrimPrefix(line, "frameworkPath:"))
					fwPath = strings.Trim(fwPath, "\"'")
					renderPath := filepath.Join(cwd, fwPath, "factory", "render.k")
					if _, err := os.Stat(renderPath); err == nil {
						return renderPath
					}
				}
			}
		}
	}

	return ""
}

package cmd

import (
	"fmt"
	"path/filepath"
	"time"

	"github.com/idp-concept/koncept/internal/config"
	"github.com/idp-concept/koncept/internal/factory"
	"github.com/idp-concept/koncept/internal/output"
	"github.com/spf13/cobra"
)

var validFormats = []string{
	"yaml", "argocd", "helm", "helmfile",
	"kusion", "kustomize", "timoni", "crossplane", "backstage",
}

// OutputTier defines support levels for each output format.
//   - Tier 1: production-ready, fully tested, golden snapshots, documented workflows
//   - Tier 2: maintained for infrastructure/platform teams, real adoption emerging
//   - Tier 3: experimental or transitional, gated behind adoption signals
var outputTiers = map[string]struct {
	tier        string
	description string
}{
	"yaml":       {"Tier 1", "Plain Kubernetes YAML (GitOps standard)"},
	"argocd":     {"Tier 1", "ArgoCD Application CRDs (GitOps standard)"},
	"helmfile":   {"Tier 1", "Helmfile +orchestration (Helm orchestration standard)"},
	"backstage":  {"Tier 1", "Backstage catalog entities (developer portal standard)"},
	"helm":       {"Tier 2", "Helm Chart structure (output for helm/helmfile; hand-author Chart.yaml)"},
	"crossplane": {"Tier 2", "Crossplane XRD/Composition/XR (infrastructure-as-code for cloud services)"},
	"kustomize":  {"Tier 2", "Kustomization overlays (emerging alternative to Helm)"},
	"kusion":     {"Tier 3", "Kusion spec format (experimental; no active internal consumer)"},
	"timoni":     {"Tier 3", "Timoni CUE modules (experimental; no active internal consumer)"},
}

var renderCmd = &cobra.Command{
	Use:       "render [format]",
	Short:     "Render KCL configurations to the specified output format",
	Long: fmt.Sprintf(`Render generates Kubernetes manifests from KCL factory configurations.

Supported formats by tier:

TIER 1 (production-ready, fully tested):
  yaml       – Plain Kubernetes YAML (GitOps standard)
  argocd     – ArgoCD Application CRDs (GitOps standard)
  helmfile   – Helmfile + orchestration (Helm orchestration standard)
  backstage  – Backstage catalog entities (developer portal standard)

TIER 2 (maintained for platform/infrastructure teams):
  helm       – Helm Chart structure (use for Helmfile or custom delivery)
  crossplane – Crossplane XRD/Composition/XR (infrastructure-as-code)
  kustomize  – Kustomization overlays (Helm alternative)

TIER 3 (experimental, gated behind adoption signals):
  kusion     – Kusion spec format (no active consumer)
  timoni     – Timoni CUE modules (no active consumer)
`),
	ValidArgs: validFormats,
	Args:      cobra.MaximumNArgs(1),
	RunE:      runRender,
}

func runRender(cmd *cobra.Command, args []string) error {
	cfg := config.Load(".")
	format := cfg.Spec.DefaultOutput
	if len(args) > 0 {
		format = args[0]
	}

	// Warn on Tier-3 formats
	if tierInfo, ok := outputTiers[format]; ok && tierInfo.tier == "Tier 3" {
		fmt.Printf("⚠️  Warning: %s is %s (experimental, no active consumer).\n", format, tierInfo.tier)
		fmt.Printf("   For production use, prefer Tier-1 outputs: yaml, argocd, helmfile, backstage\n\n")
	}

	start := time.Now()
	err := renderFormat(cfg, format)
	recorder().Record("render", format, time.Since(start), err)
	return err
}

func renderFormat(cfg *config.ProjectConfig, format string) error {
	if !factory.HasRenderK(factoryDir) {
		return fmt.Errorf("render.k not found in %s — run 'koncept init' first", factoryDir)
	}

	switch format {
	case "yaml", "argocd":
		return renderYAML(cfg, format)
	case "helmfile":
		return renderHelmfile(cfg)
	case "helm":
		return renderHelm(cfg)
	case "kusion":
		return renderKusion(cfg)
	case "kustomize":
		return renderKustomize(cfg)
	case "timoni":
		return renderTimoni(cfg)
	case "crossplane":
		return renderCrossplane(cfg)
	case "backstage":
		return renderBackstage(cfg)
	default:
		return fmt.Errorf("unsupported format: %s\nValid formats: %v", format, validFormats)
	}
}

func resolveOutputDir(cfg *config.ProjectConfig) string {
	if outputDir != "" {
		return outputDir
	}
	if cfg.Spec.Output.DefaultDir != "" {
		return cfg.Spec.Output.DefaultDir
	}
	return "output"
}

func renderYAML(cfg *config.ProjectConfig, format string) error {
	// For argocd, use "yaml" format to get plain K8s YAML
	kclFormat := format
	if format == "argocd" {
		kclFormat = "yaml"
	}

	fmt.Printf("[%s] Generating manifests...\n", format)
	result, err := factory.Render(factoryDir, kclFormat)
	if err != nil {
		printError(fmt.Sprintf("Render failed: %v", err))
		return err
	}

	outDir := resolveOutputDir(cfg)
	outFile := filepath.Join(outDir, "kubernetes_manifests.yaml")
	if err := output.WriteYAML(result, outFile); err != nil {
		return err
	}
	printSuccess(fmt.Sprintf("Manifests written to %s", outFile))
	return nil
}

func renderHelmfile(cfg *config.ProjectConfig) error {
	fmt.Println("[Helmfile] Generating parameterized Helm charts (Strategy B)...")

	// Generate Chart.yaml + values.yaml
	helmData, err := factory.Render(factoryDir, "helm")
	if err != nil {
		return fmt.Errorf("helm render failed: %w", err)
	}

	outDir := resolveOutputDir(cfg)
	helmTemplatesDir := cfg.Spec.Output.HelmTemplatesDir
	if helmTemplatesDir == "" {
		// Try default location
		helmTemplatesDir = "framework/templates/helm"
	}

	if err := output.WriteHelmCharts(helmData, outDir, helmTemplatesDir); err != nil {
		return err
	}

	// Generate helmfile.yaml
	helmfileData, err := factory.Render(factoryDir, "helmfile")
	if err != nil {
		return fmt.Errorf("helmfile render failed: %w", err)
	}
	if err := output.WriteYAML(helmfileData, filepath.Join(outDir, "helmfile.yaml")); err != nil {
		return err
	}

	printSuccess("Helmfile generation complete")
	return nil
}

func renderHelm(cfg *config.ProjectConfig) error {
	fmt.Println("[Helm] Generating Helm chart data...")
	helmData, err := factory.Render(factoryDir, "helm")
	if err != nil {
		return err
	}

	outDir := resolveOutputDir(cfg)
	helmTemplatesDir := cfg.Spec.Output.HelmTemplatesDir
	if helmTemplatesDir == "" {
		helmTemplatesDir = "framework/templates/helm"
	}
	return output.WriteHelmCharts(helmData, outDir, helmTemplatesDir)
}

func renderKusion(cfg *config.ProjectConfig) error {
	fmt.Println("[Kusion] Generating Kusion spec...")
	result, err := factory.Render(factoryDir, "kusion")
	if err != nil {
		return err
	}

	outDir := resolveOutputDir(cfg)
	outFile := filepath.Join(outDir, "kusion_spec.yaml")
	if err := output.WriteYAML(result, outFile); err != nil {
		return err
	}
	printSuccess(fmt.Sprintf("Kusion spec written to %s", outFile))
	return nil
}

func renderKustomize(cfg *config.ProjectConfig) error {
	fmt.Println("[Kustomize] Generating base manifests and kustomization.yaml...")

	kustomizeData, err := factory.Render(factoryDir, "kustomize")
	if err != nil {
		return err
	}

	manifestsData, err := factory.Render(factoryDir, "yaml")
	if err != nil {
		return err
	}

	outDir := resolveOutputDir(cfg)
	if err := output.WriteKustomize(kustomizeData, manifestsData, outDir); err != nil {
		return err
	}
	printSuccess("Kustomize output complete")
	return nil
}

func renderTimoni(cfg *config.ProjectConfig) error {
	fmt.Println("[Timoni] Generating CUE module...")
	result, err := factory.Render(factoryDir, "timoni")
	if err != nil {
		return err
	}

	outDir := resolveOutputDir(cfg)
	outFile := filepath.Join(outDir, "timoni", "module.yaml")
	if err := output.WriteYAML(result, outFile); err != nil {
		return err
	}
	printSuccess("Timoni module generated")
	return nil
}

func renderCrossplane(cfg *config.ProjectConfig) error {
	fmt.Println("[Crossplane] Generating XRD, Composition, and XR...")
	result, err := factory.Render(factoryDir, "crossplane")
	if err != nil {
		return err
	}

	outDir := resolveOutputDir(cfg)
	if err := output.WriteCrossplane(result, outDir); err != nil {
		return err
	}
	printSuccess("Crossplane output complete")
	return nil
}

func renderBackstage(cfg *config.ProjectConfig) error {
	fmt.Println("[Backstage] Generating catalog-info.yaml entities...")
	result, err := factory.Render(factoryDir, "backstage")
	if err != nil {
		return err
	}

	outDir := resolveOutputDir(cfg)
	if err := output.WriteBackstage(result, outDir); err != nil {
		return err
	}
	printSuccess("Backstage catalog generated")
	return nil
}

func init() {
	// Suggest completions for render argument
	renderCmd.RegisterFlagCompletionFunc("output", func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		return validFormats, cobra.ShellCompDirectiveNoFileComp
	})
}

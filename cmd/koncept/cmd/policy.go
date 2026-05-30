package cmd

import (
	"fmt"

	"github.com/idp-concept/koncept/internal/factory"
	"github.com/idp-concept/koncept/internal/policy"
	"github.com/spf13/cobra"
)

var (
	policyFormat       string
	policyWarnAsError  bool
	policyNoResources  bool
	policyNoOwnerCheck bool
	policyNoSecretRefs bool
	policyNoNamespace  bool
	policyNoNetPol     bool
)

var policyCmd = &cobra.Command{
	Use:   "policy [check]",
	Short: "Enforce baseline security and ownership policies on rendered manifests",
	Long: `policy renders the factory output and checks it against baseline platform policies:

  - no privileged containers, privilege escalation, or hostNetwork
  - no 'latest' or untagged images (must be version- or digest-pinned)
  - Tier-1 workloads (Deployment/StatefulSet/DaemonSet) must declare resource
    requests and limits
  - Tier-1 workloads should carry an ownership label
  - secret-looking env values must use a Secret reference (no literals)
  - Tier-1 workloads should declare an explicit namespace
  - namespaces running workloads should have a NetworkPolicy (default-deny)

Errors fail the command (exit 1). Warnings are reported but do not fail unless
--warn-as-error is set.`,
	Args:      cobra.MaximumNArgs(1),
	ValidArgs: []string{"check"},
	RunE:      runPolicy,
}

func runPolicy(cmd *cobra.Command, args []string) error {
	if !factory.HasRenderK(factoryDir) {
		return fmt.Errorf("render.k not found in %s — run from a factory directory or pass --factory", factoryDir)
	}

	kclFormat := policyFormat
	if kclFormat == "argocd" {
		kclFormat = "yaml"
	}

	printInfo(fmt.Sprintf("policy: rendering %s from %s", policyFormat, factoryDir))
	rendered, err := factory.Render(factoryDir, kclFormat)
	if err != nil {
		return err
	}

	opts := policy.DefaultOptions()
	opts.RequireResources = !policyNoResources
	opts.RequireOwner = !policyNoOwnerCheck
	opts.RequireSecretRefs = !policyNoSecretRefs
	opts.RequireNamespace = !policyNoNamespace
	opts.RequireNetworkPolicy = !policyNoNetPol

	findings, err := policy.Check(rendered, opts)
	if err != nil {
		return fmt.Errorf("policy check failed: %w", err)
	}

	errors, warnings := 0, 0
	for _, f := range findings {
		switch f.Severity {
		case policy.SeverityError:
			errors++
		case policy.SeverityWarning:
			warnings++
		}
		fmt.Printf("  %s\n", f.String())
	}

	if errors == 0 && warnings == 0 {
		printSuccess("policy: all checks passed")
		return nil
	}

	fmt.Printf("\n  %d error(s), %d warning(s)\n", errors, warnings)
	if errors > 0 || (policyWarnAsError && warnings > 0) {
		return fmt.Errorf("policy check failed")
	}
	printSuccess("policy: no blocking violations")
	return nil
}

func init() {
	policyCmd.Flags().StringVar(&policyFormat, "format", "yaml", "render format to evaluate (yaml|argocd)")
	policyCmd.Flags().BoolVar(&policyWarnAsError, "warn-as-error", false, "treat warnings as failures")
	policyCmd.Flags().BoolVar(&policyNoResources, "no-require-resources", false, "disable the resource requests/limits rule")
	policyCmd.Flags().BoolVar(&policyNoOwnerCheck, "no-require-owner", false, "disable the ownership label rule")
	policyCmd.Flags().BoolVar(&policyNoSecretRefs, "no-require-secret-refs", false, "disable the secret-literal env rule")
	policyCmd.Flags().BoolVar(&policyNoNamespace, "no-require-namespace", false, "disable the explicit namespace rule")
	policyCmd.Flags().BoolVar(&policyNoNetPol, "no-require-network-policy", false, "disable the per-namespace NetworkPolicy rule")
}

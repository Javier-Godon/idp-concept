package crossplane

import (
	"fmt"
	"os/exec"
	"path/filepath"
)

const (
	RuntimeModeNone         = "none"
	RuntimeModeServerDryRun = "server-dry-run"
	RuntimeModeApplyDelete  = "apply-delete"

	RuntimeProfileNone         = "none"
	RuntimeProfileSmoke        = "smoke"
	RuntimeProfileLifecycle    = "lifecycle"
	RuntimeProfileCatalog      = "catalog"
	RuntimeProfileAPILifecycle = "api-lifecycle"
)

// ValidateRuntimeMode checks if a runtime mode is supported.
func ValidateRuntimeMode(mode string) error {
	switch mode {
	case RuntimeModeNone, RuntimeModeServerDryRun, RuntimeModeApplyDelete:
		return nil
	default:
		return fmt.Errorf("invalid runtime mode %q (use one of: %s, %s, %s)", mode, RuntimeModeNone, RuntimeModeServerDryRun, RuntimeModeApplyDelete)
	}
}

// ValidateRuntimeProfile checks if a runtime profile is supported.
func ValidateRuntimeProfile(profile string) error {
	switch profile {
	case RuntimeProfileNone, RuntimeProfileSmoke, RuntimeProfileLifecycle, RuntimeProfileCatalog, RuntimeProfileAPILifecycle:
		return nil
	default:
		return fmt.Errorf("invalid runtime profile %q (use one of: %s, %s, %s, %s, %s)", profile, RuntimeProfileNone, RuntimeProfileSmoke, RuntimeProfileLifecycle, RuntimeProfileCatalog, RuntimeProfileAPILifecycle)
	}
}

// RuntimeOptions controls optional kubectl-based Crossplane runtime checks.
type RuntimeOptions struct {
	Mode                 string
	KubeContext          string
	Timeout              string
	IncludePrerequisites bool
	Cleanup              bool
	CleanupPrerequisites bool
}

// ResolveRuntimeOptions merges a runtime profile into explicit runtime options.
// Profiles are mutually exclusive with an explicit non-none mode.
func ResolveRuntimeOptions(profile string, opts RuntimeOptions) (RuntimeOptions, error) {
	if err := ValidateRuntimeProfile(profile); err != nil {
		return opts, err
	}
	if err := ValidateRuntimeMode(opts.Mode); err != nil {
		return opts, err
	}
	if profile == RuntimeProfileNone {
		return opts, nil
	}
	if opts.Mode != "" && opts.Mode != RuntimeModeNone {
		return opts, fmt.Errorf("runtime profile %q cannot be combined with explicit runtime mode %q", profile, opts.Mode)
	}

	switch profile {
	case RuntimeProfileSmoke:
		opts.Mode = RuntimeModeServerDryRun
		return opts, nil
	case RuntimeProfileLifecycle:
		opts.Mode = RuntimeModeApplyDelete
		if opts.Timeout == "" {
			opts.Timeout = "120s"
		}
		opts.Cleanup = true
		return opts, nil
	case RuntimeProfileCatalog:
		opts.Mode = RuntimeModeServerDryRun
		opts.IncludePrerequisites = true
		opts.Cleanup = false
		opts.CleanupPrerequisites = false
		return opts, nil
	case RuntimeProfileAPILifecycle:
		opts.Mode = RuntimeModeApplyDelete
		opts.IncludePrerequisites = false
		if opts.Timeout == "" {
			opts.Timeout = "180s"
		}
		opts.Cleanup = true
		opts.CleanupPrerequisites = false
		return opts, nil
	default:
		return opts, nil
	}
}

// RunRuntimeChecks executes optional kubectl checks against generated artifacts.
func RunRuntimeChecks(artifactsDir string, opts RuntimeOptions) error {
	if err := ValidateRuntimeMode(opts.Mode); err != nil {
		return err
	}
	if opts.Mode == RuntimeModeNone {
		return nil
	}
	if _, err := exec.LookPath("kubectl"); err != nil {
		return fmt.Errorf("kubectl is required for runtime mode %q", opts.Mode)
	}

	crossplaneDir := filepath.Join(artifactsDir, "crossplane")
	prereqFile := filepath.Join(crossplaneDir, "prerequisites", "infrastructure.yaml")
	xrdFile := filepath.Join(crossplaneDir, "xrd.yaml")
	compositionFile := filepath.Join(crossplaneDir, "composition.yaml")
	xrFile := filepath.Join(crossplaneDir, "xr.yaml")

	applyOrder := []string{}
	if opts.IncludePrerequisites {
		applyOrder = append(applyOrder, prereqFile)
	}
	applyOrder = append(applyOrder, xrdFile, compositionFile, xrFile)

	switch opts.Mode {
	case RuntimeModeServerDryRun:
		for _, file := range applyOrder {
			if err := kubectl(opts.KubeContext, "apply", "--dry-run=server", "-f", file); err != nil {
				return err
			}
		}
		return nil
	case RuntimeModeApplyDelete:
		for _, file := range applyOrder {
			if err := kubectl(opts.KubeContext, "apply", "-f", file); err != nil {
				return err
			}
		}
		if opts.Timeout == "" {
			opts.Timeout = "120s"
		}
		if err := kubectl(opts.KubeContext, "wait", "--for=condition=Ready", "--timeout="+opts.Timeout, "-f", xrFile); err != nil {
			return err
		}
		if !opts.Cleanup {
			return nil
		}
		if err := kubectl(opts.KubeContext, "delete", "--ignore-not-found", "-f", xrFile); err != nil {
			return err
		}
		if err := kubectl(opts.KubeContext, "delete", "--ignore-not-found", "-f", compositionFile); err != nil {
			return err
		}
		if err := kubectl(opts.KubeContext, "delete", "--ignore-not-found", "-f", xrdFile); err != nil {
			return err
		}
		if opts.IncludePrerequisites && opts.CleanupPrerequisites {
			if err := kubectl(opts.KubeContext, "delete", "--ignore-not-found", "-f", prereqFile); err != nil {
				return err
			}
		}
		return nil
	default:
		return nil
	}
}

func kubectl(kubeContext string, args ...string) error {
	fullArgs := []string{}
	if kubeContext != "" {
		fullArgs = append(fullArgs, "--context", kubeContext)
	}
	fullArgs = append(fullArgs, args...)
	cmd := exec.Command("kubectl", fullArgs...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("kubectl %v failed: %w\n%s", fullArgs, err, string(out))
	}
	return nil
}

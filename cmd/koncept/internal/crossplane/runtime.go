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

// RuntimeOptions controls optional kubectl-based Crossplane runtime checks.
type RuntimeOptions struct {
	Mode                 string
	KubeContext          string
	Timeout              string
	IncludePrerequisites bool
	Cleanup              bool
	CleanupPrerequisites bool
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

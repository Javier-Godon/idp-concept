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
	RuntimeProfileMatrix       = "matrix"
)

var matrixProfiles = []string{RuntimeProfileSmoke, RuntimeProfileCatalog, RuntimeProfileAPILifecycle}

func isMatrixStep(profile string) bool {
	for _, step := range matrixProfiles {
		if profile == step {
			return true
		}
	}
	return false
}

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
	case RuntimeProfileNone, RuntimeProfileSmoke, RuntimeProfileLifecycle, RuntimeProfileCatalog, RuntimeProfileAPILifecycle, RuntimeProfileMatrix:
		return nil
	default:
		return fmt.Errorf("invalid runtime profile %q (use one of: %s, %s, %s, %s, %s, %s)", profile, RuntimeProfileNone, RuntimeProfileSmoke, RuntimeProfileLifecycle, RuntimeProfileCatalog, RuntimeProfileAPILifecycle, RuntimeProfileMatrix)
	}
}

// ExpandRuntimeProfiles expands a runtime profile into one or more concrete
// profile steps. The matrix profile runs a standard progression from low-risk
// checks toward API-lifecycle validation.
func ExpandRuntimeProfiles(profile string) ([]string, error) {
	if err := ValidateRuntimeProfile(profile); err != nil {
		return nil, err
	}
	if profile != RuntimeProfileMatrix {
		return []string{profile}, nil
	}
	return append([]string{}, matrixProfiles...), nil
}

// SelectMatrixProfiles returns a contiguous subset of matrix profiles from
// optional start/end boundaries. Both boundaries are inclusive.
func SelectMatrixProfiles(profiles []string, from string, stopOn string) ([]string, error) {
	if len(profiles) == 0 {
		return nil, fmt.Errorf("matrix profiles list is empty")
	}
	if from != "" && !isMatrixStep(from) {
		return nil, fmt.Errorf("invalid runtime matrix from-step %q", from)
	}
	if stopOn != "" && !isMatrixStep(stopOn) {
		return nil, fmt.Errorf("invalid runtime matrix stop-step %q", stopOn)
	}

	start := 0
	end := len(profiles) - 1
	if from != "" {
		for i, profile := range profiles {
			if profile == from {
				start = i
				break
			}
		}
	}
	if stopOn != "" {
		for i, profile := range profiles {
			if profile == stopOn {
				end = i
				break
			}
		}
	}
	if start > end {
		return nil, fmt.Errorf("matrix from-step %q comes after stop-step %q", from, stopOn)
	}
	return append([]string{}, profiles[start:end+1]...), nil
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

// RuntimeStep is a resolved runtime execution step.
type RuntimeStep struct {
	Profile string
	Options RuntimeOptions
}

// PlanRuntimeSequence resolves a runtime profile and optional matrix boundaries
// into concrete runtime execution steps.
func PlanRuntimeSequence(profile string, matrixFrom string, matrixStopOn string, base RuntimeOptions) ([]RuntimeStep, error) {
	profiles, err := ExpandRuntimeProfiles(profile)
	if err != nil {
		return nil, err
	}
	if (matrixFrom != "" || matrixStopOn != "") && profile != RuntimeProfileMatrix {
		return nil, fmt.Errorf("--runtime-matrix-from/--runtime-matrix-stop-on require --runtime-profile matrix")
	}
	if profile == RuntimeProfileMatrix {
		profiles, err = SelectMatrixProfiles(profiles, matrixFrom, matrixStopOn)
		if err != nil {
			return nil, err
		}
	}

	steps := []RuntimeStep{}
	for _, p := range profiles {
		runtimeOpts, err := ResolveRuntimeOptions(p, base)
		if err != nil {
			return nil, err
		}
		if runtimeOpts.Mode == RuntimeModeNone {
			continue
		}
		steps = append(steps, RuntimeStep{Profile: p, Options: runtimeOpts})
	}
	return steps, nil
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
	if profile == RuntimeProfileMatrix {
		return opts, fmt.Errorf("runtime profile %q must be expanded with ExpandRuntimeProfiles before resolving options", RuntimeProfileMatrix)
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

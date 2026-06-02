package crossplane

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/idp-concept/koncept/internal/output"
	"gopkg.in/yaml.v3"
)

const (
	requiredXRDKind         = "CompositeResourceDefinition"
	requiredCompositionKind = "Composition"
	requiredXRAPIPrefix     = "koncept.bluesolution.es/"
)

// Report is the outcome of a Crossplane output verification run.
type Report struct {
	Warnings            []string
	FunctionPackages    []string
	ProviderPackages    []string
	CrossplaneRenderRan bool
	CrossplaneRenderOut string
	ArtifactsDir        string
	StaticChecksPassed  bool
}

// ValidateRenderedOutput validates rendered crossplane output YAML and can
// optionally execute `crossplane render` when the binary is available.
func ValidateRenderedOutput(rendered string, runRender bool, requireCLI bool) (Report, error) {
	report := Report{}
	parsed, err := parseRendered(rendered)
	if err != nil {
		return report, err
	}

	if err := validateStatic(parsed, &report); err != nil {
		return report, err
	}
	report.StaticChecksPassed = true

	tmpDir, err := os.MkdirTemp("", "koncept-crossplane-test-*")
	if err != nil {
		return report, fmt.Errorf("create temporary directory: %w", err)
	}
	report.ArtifactsDir = tmpDir

	if err := output.WriteCrossplane(rendered, tmpDir); err != nil {
		return report, fmt.Errorf("write crossplane artifacts: %w", err)
	}

	if !runRender {
		return report, nil
	}

	if _, err := exec.LookPath("crossplane"); err != nil {
		if requireCLI {
			return report, fmt.Errorf("crossplane CLI is required but not found in PATH")
		}
		report.Warnings = append(report.Warnings, "crossplane CLI not found in PATH; skipping local composition render")
		return report, nil
	}

	functionsFile, err := writeFunctionsFile(tmpDir, parsed.Prerequisites)
	if err != nil {
		return report, err
	}

	cmd := exec.Command(
		"crossplane",
		"render",
		filepath.Join(tmpDir, "crossplane", "xr.yaml"),
		filepath.Join(tmpDir, "crossplane", "composition.yaml"),
		functionsFile,
		"--include-function-results",
	)
	out, err := cmd.CombinedOutput()
	report.CrossplaneRenderOut = strings.TrimSpace(string(out))
	if err != nil {
		return report, fmt.Errorf("crossplane render failed: %w\n%s", err, string(out))
	}
	report.CrossplaneRenderRan = true

	return report, nil
}

type renderedOutput struct {
	XRD           map[string]any
	Composition   map[string]any
	XR            map[string]any
	Prerequisites []map[string]any
}

func parseRendered(rendered string) (renderedOutput, error) {
	var raw map[string]any
	if err := yaml.Unmarshal([]byte(rendered), &raw); err != nil {
		return renderedOutput{}, fmt.Errorf("parse rendered crossplane output: %w", err)
	}

	xrd, ok := raw["xrd"].(map[string]any)
	if !ok {
		return renderedOutput{}, errors.New("crossplane output missing xrd section")
	}
	composition, ok := raw["composition"].(map[string]any)
	if !ok {
		return renderedOutput{}, errors.New("crossplane output missing composition section")
	}
	xr, ok := raw["xr"].(map[string]any)
	if !ok {
		return renderedOutput{}, errors.New("crossplane output missing xr section")
	}

	prerequisites := toMapSlice(raw["prerequisites"])
	if len(prerequisites) == 0 {
		return renderedOutput{}, errors.New("crossplane output missing prerequisites section")
	}

	return renderedOutput{XRD: xrd, Composition: composition, XR: xr, Prerequisites: prerequisites}, nil
}

func validateStatic(parsed renderedOutput, report *Report) error {
	if kind(parsed.XRD) != requiredXRDKind {
		return fmt.Errorf("xrd.kind must be %s", requiredXRDKind)
	}
	if kind(parsed.Composition) != requiredCompositionKind {
		return fmt.Errorf("composition.kind must be %s", requiredCompositionKind)
	}

	mode := nestedString(parsed.Composition, "spec", "mode")
	if mode != "Pipeline" {
		return fmt.Errorf("composition.spec.mode must be Pipeline")
	}
	steps := pipelineSteps(parsed.Composition)
	if !contains(steps, "render-manifests") || !contains(steps, "automatically-detect-readiness") {
		return fmt.Errorf("composition pipeline must include render-manifests and automatically-detect-readiness")
	}

	xrAPIVersion := nestedString(parsed.XR, "apiVersion")
	if !strings.HasPrefix(xrAPIVersion, requiredXRAPIPrefix) {
		return fmt.Errorf("xr.apiVersion must start with %s", requiredXRAPIPrefix)
	}

	providers := 0
	functions := 0
	for _, resource := range parsed.Prerequisites {
		k := kind(resource)
		pkg := nestedString(resource, "spec", "package")
		if k == "Provider" {
			providers++
			if !isPinnedPackage(pkg) {
				return fmt.Errorf("provider package must be pinned (no latest/empty): %q", pkg)
			}
			report.ProviderPackages = append(report.ProviderPackages, pkg)
		}
		if k == "Function" {
			functions++
			if !isPinnedPackage(pkg) {
				return fmt.Errorf("function package must be pinned (no latest/empty): %q", pkg)
			}
			report.FunctionPackages = append(report.FunctionPackages, pkg)
		}
	}
	if providers < 2 {
		return fmt.Errorf("expected at least 2 Provider resources in prerequisites, got %d", providers)
	}
	if functions < 3 {
		return fmt.Errorf("expected at least 3 Function resources in prerequisites, got %d", functions)
	}

	return nil
}

func writeFunctionsFile(baseDir string, prerequisites []map[string]any) (string, error) {
	path := filepath.Join(baseDir, "crossplane", "functions.yaml")
	parts := []string{}
	for _, resource := range prerequisites {
		if kind(resource) != "Function" {
			continue
		}
		b, err := yaml.Marshal(resource)
		if err != nil {
			return "", fmt.Errorf("marshal function resource: %w", err)
		}
		parts = append(parts, strings.TrimSpace(string(b)))
	}
	if len(parts) == 0 {
		return "", errors.New("no Function resources found in prerequisites")
	}
	content := strings.Join(parts, "\n---\n") + "\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return "", fmt.Errorf("write functions file: %w", err)
	}
	return path, nil
}

func toMapSlice(v any) []map[string]any {
	items, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]map[string]any, 0, len(items))
	for _, item := range items {
		if m, ok := item.(map[string]any); ok {
			out = append(out, m)
		}
	}
	return out
}

func kind(doc map[string]any) string {
	v, _ := doc["kind"].(string)
	return v
}

func nestedString(doc map[string]any, keys ...string) string {
	if len(keys) == 1 {
		v, _ := doc[keys[0]].(string)
		return v
	}
	cur := any(doc)
	for _, k := range keys {
		m, ok := cur.(map[string]any)
		if !ok {
			return ""
		}
		cur = m[k]
	}
	v, _ := cur.(string)
	return v
}

func pipelineSteps(composition map[string]any) []string {
	spec, _ := composition["spec"].(map[string]any)
	pipeline, _ := spec["pipeline"].([]any)
	steps := make([]string, 0, len(pipeline))
	for _, step := range pipeline {
		m, ok := step.(map[string]any)
		if !ok {
			continue
		}
		name, _ := m["step"].(string)
		if name != "" {
			steps = append(steps, name)
		}
	}
	return steps
}

func contains(items []string, target string) bool {
	for _, item := range items {
		if item == target {
			return true
		}
	}
	return false
}

func isPinnedPackage(pkg string) bool {
	if strings.TrimSpace(pkg) == "" {
		return false
	}
	if strings.Contains(strings.ToLower(pkg), "latest") {
		return false
	}
	return strings.Contains(pkg, ":")
}

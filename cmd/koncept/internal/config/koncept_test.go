package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadDefaultsFrameworkSource(t *testing.T) {
	cfg := Load(t.TempDir())

	if cfg.Spec.Framework.Source != "local" {
		t.Fatalf("default framework source = %q, want local", cfg.Spec.Framework.Source)
	}
	if cfg.Spec.DefaultOutput != "yaml" {
		t.Fatalf("default output = %q, want yaml", cfg.Spec.DefaultOutput)
	}
}

func TestLoadFrameworkCompatibilityConfig(t *testing.T) {
	dir := t.TempDir()
	data := []byte(`apiVersion: koncept.bluesolution.es/v1
kind: ProjectConfig
metadata:
  name: inventory_service
spec:
  frameworkPath: ../../framework
  framework:
    source: git
    version: v0.2.0
    versionConstraint: ">=0.2.0 <0.3.0"
    supportTier: tier-1
    supportWindow: "one minor release"
    testedVersions:
      - v0.2.0
  defaultOutput: argocd
`)
	if err := os.WriteFile(filepath.Join(dir, "koncept.yaml"), data, 0o644); err != nil {
		t.Fatalf("write config: %v", err)
	}

	cfg := Load(dir)

	if cfg.Spec.FrameworkPath != "../../framework" {
		t.Fatalf("framework path = %q", cfg.Spec.FrameworkPath)
	}
	if cfg.Spec.Framework.Source != "git" {
		t.Fatalf("framework source = %q", cfg.Spec.Framework.Source)
	}
	if cfg.Spec.Framework.VersionConstraint != ">=0.2.0 <0.3.0" {
		t.Fatalf("framework constraint = %q", cfg.Spec.Framework.VersionConstraint)
	}
	if len(cfg.Spec.Framework.TestedVersions) != 1 || cfg.Spec.Framework.TestedVersions[0] != "v0.2.0" {
		t.Fatalf("tested versions = %#v", cfg.Spec.Framework.TestedVersions)
	}
}

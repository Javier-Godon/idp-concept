package factory

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDeriveConventionContextForPreRelease(t *testing.T) {
	root := t.TempDir()
	projectRoot := filepath.Join(root, "projects", "erp_back")
	factoryDir := filepath.Join(projectRoot, "pre_releases", "manifests", "dev", "factory")
	if err := os.MkdirAll(factoryDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(projectRoot, "kcl.mod"), []byte("[package]\nname = \"erp_back\"\nversion = \"0.0.1\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	ctx := DeriveConventionContext(factoryDir)
	assertEqual(t, ctx.ProjectSlug, "erp_back")
	assertEqual(t, ctx.ProjectVersion, "0.0.1")
	assertEqual(t, ctx.ReleaseKind, "pre_release")
	assertEqual(t, ctx.ReleaseID, "dev")
	assertEqual(t, ctx.Environment, "dev")
	assertEqual(t, ctx.Version, "0.0.1-dev")
	assertEqual(t, ctx.ReleaseName, "pre_release_dev")
	assertEqual(t, ctx.ManifestPath, "projects/erp_back/pre_releases/manifests/dev/output")
}

func TestDeriveConventionContextForRelease(t *testing.T) {
	root := t.TempDir()
	projectRoot := filepath.Join(root, "projects", "erp_back")
	factoryDir := filepath.Join(projectRoot, "releases", "v1_0_0_production", "factory")
	if err := os.MkdirAll(factoryDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(projectRoot, "kcl.mod"), []byte("[package]\nname = \"erp_back\"\nversion = \"0.0.1\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	ctx := DeriveConventionContext(factoryDir)
	assertEqual(t, ctx.ProjectSlug, "erp_back")
	assertEqual(t, ctx.ReleaseKind, "release")
	assertEqual(t, ctx.ReleaseID, "v1_0_0_production")
	assertEqual(t, ctx.Environment, "production")
	assertEqual(t, ctx.Version, "1.0.0")
	assertEqual(t, ctx.ReleaseName, "release_v1_0_0_production")
	assertEqual(t, ctx.ManifestPath, "projects/erp_back/releases/v1_0_0_production/output")
}

func assertEqual(t *testing.T, got, want string) {
	t.Helper()
	if got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

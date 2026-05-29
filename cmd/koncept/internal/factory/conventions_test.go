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

func TestFindModuleRootUsesNearestKCLMod(t *testing.T) {
	root := t.TempDir()
	projectRoot := filepath.Join(root, "projects", "erp_back")
	preReleaseRoot := filepath.Join(projectRoot, "pre_releases")
	factoryDir := filepath.Join(preReleaseRoot, "manifests", "dev", "factory")
	if err := os.MkdirAll(factoryDir, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, dir := range []string{projectRoot, preReleaseRoot} {
		if err := os.WriteFile(filepath.Join(dir, "kcl.mod"), []byte("[package]\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	moduleRoot, err := FindModuleRoot(factoryDir)
	if err != nil {
		t.Fatal(err)
	}
	assertEqual(t, moduleRoot, preReleaseRoot)
}

func TestResolveKCLFileReturnsModuleRelativePath(t *testing.T) {
	root := t.TempDir()
	preReleaseRoot := filepath.Join(root, "projects", "erp_back", "pre_releases")
	factoryDir := filepath.Join(preReleaseRoot, "manifests", "dev", "factory")
	if err := os.MkdirAll(factoryDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(preReleaseRoot, "kcl.mod"), []byte("[package]\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(factoryDir, "render.k"), []byte("_out = 1\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	moduleRoot, relFile, err := resolveKCLFile(factoryDir, "render.k")
	if err != nil {
		t.Fatal(err)
	}
	assertEqual(t, moduleRoot, preReleaseRoot)
	assertEqual(t, relFile, "manifests/dev/factory/render.k")
}

func TestLocalDependencyOptionsIncludesTransitivePathDependencies(t *testing.T) {
	root := t.TempDir()
	frameworkRoot := filepath.Join(root, "framework")
	projectRoot := filepath.Join(root, "projects", "erp_back")
	preReleaseRoot := filepath.Join(projectRoot, "pre_releases")
	for _, dir := range []string{frameworkRoot, projectRoot, preReleaseRoot} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	files := map[string]string{
		filepath.Join(frameworkRoot, "kcl.mod"):  "[package]\nname = \"framework\"\n",
		filepath.Join(projectRoot, "kcl.mod"):    "[package]\nname = \"erp_back\"\n\n[dependencies]\nframework = { path = \"../../framework\" }\nk8s = \"1.31.2\"\n",
		filepath.Join(preReleaseRoot, "kcl.mod"): "[package]\nname = \"pre_releases\"\n\n[dependencies]\nerp_back = { path = \"../../erp_back\" }\n",
	}
	for path, content := range files {
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	options := LocalDependencyOptions(preReleaseRoot)
	assertStringSliceContains(t, options, "erp_back="+projectRoot)
	assertStringSliceContains(t, options, "framework="+frameworkRoot)
}

func assertEqual(t *testing.T, got, want string) {
	t.Helper()
	if got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func assertStringSliceContains(t *testing.T, values []string, want string) {
	t.Helper()
	for _, value := range values {
		if value == want {
			return
		}
	}
	t.Fatalf("%v does not contain %q", values, want)
}

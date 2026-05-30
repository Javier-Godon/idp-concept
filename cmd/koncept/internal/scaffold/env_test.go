package scaffold

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNewEnvSpecPresets(t *testing.T) {
	cases := map[string]struct {
		name, wantName, wantShort, wantCluster string
	}{
		"stg":        {"stg", "staging", "stg", "stg_cluster"},
		"staging":    {"staging", "staging", "stg", "stg_cluster"},
		"prod":       {"prod", "production", "prod", "prod_cluster"},
		"production": {"production", "production", "prod", "prod_cluster"},
		"dev":        {"dev", "development", "dev", "dev_cluster"},
	}
	for key, c := range cases {
		spec := NewEnvSpec(c.name, "demo_svc")
		if spec.Name != c.wantName || spec.Short != c.wantShort || spec.Cluster != c.wantCluster {
			t.Errorf("%s: got name=%s short=%s cluster=%s, want %s/%s/%s",
				key, spec.Name, spec.Short, spec.Cluster, c.wantName, c.wantShort, c.wantCluster)
		}
		if spec.SchemaPrefix != "DemoSvc" {
			t.Errorf("%s: SchemaPrefix = %q, want DemoSvc", key, spec.SchemaPrefix)
		}
		if spec.AppsNamespace != "demo-svc-apps" {
			t.Errorf("%s: AppsNamespace = %q, want demo-svc-apps", key, spec.AppsNamespace)
		}
	}
}

func TestNewEnvSpecCustomName(t *testing.T) {
	spec := NewEnvSpec("QA-Env", "demo_svc")
	if spec.Name != "qa_env" {
		t.Errorf("Name = %q, want qa_env", spec.Name)
	}
	if spec.Short != "qa_e" {
		t.Errorf("Short = %q, want qa_e (first 4 chars)", spec.Short)
	}
}

func TestGenerateEnvRendersAllFiles(t *testing.T) {
	root := t.TempDir()
	spec := NewEnvSpec("staging", "demo_svc")
	created, err := GenerateEnv(spec, root)
	if err != nil {
		t.Fatalf("GenerateEnv: %v", err)
	}
	wantSuffixes := []string{
		"stacks/staging/stack_def.k",
		"stacks/staging/profile_configurations.k",
		"stacks/staging/profile_def.k",
		"sites/staging/stg_cluster/configurations.k",
		"sites/staging/stg_cluster/site_def.k",
		"pre_releases/configurations_stg.k",
		"pre_releases/manifests/stg/factory/render.k",
		"pre_releases/manifests/stg/factory/factory_seed.k",
	}
	if len(created) != len(wantSuffixes) {
		t.Fatalf("created %d files, want %d: %v", len(created), len(wantSuffixes), created)
	}
	for _, suf := range wantSuffixes {
		p := filepath.Join(root, filepath.FromSlash(suf))
		data, readErr := os.ReadFile(p)
		if readErr != nil {
			t.Errorf("missing %s: %v", suf, readErr)
			continue
		}
		if strings.Contains(string(data), "{{") {
			t.Errorf("unrendered template in %s", suf)
		}
	}

	stackDef, _ := os.ReadFile(filepath.Join(root, "stacks/staging/stack_def.k"))
	if !strings.Contains(string(stackDef), "schema DemoSvcStagingStack(Stack):") {
		t.Errorf("stack_def missing env stack schema:\n%s", stackDef)
	}
	seed, _ := os.ReadFile(filepath.Join(root, "pre_releases/manifests/stg/factory/factory_seed.k"))
	if !strings.Contains(string(seed), "stacks.staging.stack_def") {
		t.Errorf("factory_seed missing staging stack import:\n%s", seed)
	}
}

func TestGenerateEnvRefusesExisting(t *testing.T) {
	root := t.TempDir()
	spec := NewEnvSpec("staging", "demo_svc")
	if _, err := GenerateEnv(spec, root); err != nil {
		t.Fatalf("first GenerateEnv: %v", err)
	}
	if _, err := GenerateEnv(spec, root); err == nil {
		t.Fatal("expected error when env already exists")
	}
}

func TestVersionSlug(t *testing.T) {
	cases := map[string]string{
		"1.0.0":  "v1_0_0",
		"v1.0.0": "v1_0_0",
		"v2.1":   "v2_1",
		"":       "v0_0_0",
	}
	for in, want := range cases {
		if got := versionSlug(in); got != want {
			t.Errorf("versionSlug(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestGenerateReleaseRendersAllFiles(t *testing.T) {
	root := t.TempDir()
	spec := NewReleaseSpec("1.0.0", "demo_svc")
	created, err := GenerateRelease(spec, root)
	if err != nil {
		t.Fatalf("GenerateRelease: %v", err)
	}
	wantSuffixes := []string{
		"stacks/versioned/v1_0_0/stack_def.k",
		"stacks/versioned/v1_0_0/profile_configurations.k",
		"stacks/versioned/v1_0_0/profile_def.k",
		"sites/production/default/configurations.k",
		"sites/production/default/site_def.k",
		"releases/kcl.mod",
		"releases/v1_0_0_production/factory/render.k",
		"releases/v1_0_0_production/factory/factory_seed.k",
	}
	if len(created) != len(wantSuffixes) {
		t.Fatalf("created %d files, want %d: %v", len(created), len(wantSuffixes), created)
	}
	for _, suf := range wantSuffixes {
		data, readErr := os.ReadFile(filepath.Join(root, filepath.FromSlash(suf)))
		if readErr != nil {
			t.Errorf("missing %s: %v", suf, readErr)
			continue
		}
		if strings.Contains(string(data), "{{") {
			t.Errorf("unrendered template in %s", suf)
		}
	}

	stackDef, _ := os.ReadFile(filepath.Join(root, "stacks/versioned/v1_0_0/stack_def.k"))
	if !strings.Contains(string(stackDef), `appVersion = "1.0.0"`) {
		t.Errorf("release stack_def must pin appVersion:\n%s", stackDef)
	}
}

func TestGenerateReleaseKeepsSharedProductionSite(t *testing.T) {
	root := t.TempDir()
	if _, err := GenerateRelease(NewReleaseSpec("1.0.0", "demo_svc"), root); err != nil {
		t.Fatalf("first release: %v", err)
	}
	// A second release must not error on the shared production site / releases mod,
	// and must create its own versioned stack + factory.
	created, err := GenerateRelease(NewReleaseSpec("2.0.0", "demo_svc"), root)
	if err != nil {
		t.Fatalf("second release: %v", err)
	}
	for _, p := range created {
		if strings.Contains(p, "sites/production/default") || strings.HasSuffix(p, "releases/kcl.mod") {
			t.Errorf("second release should not recreate shared file: %s", p)
		}
	}
	if _, err := os.Stat(filepath.Join(root, "releases/v2_0_0_production/factory/factory_seed.k")); err != nil {
		t.Errorf("second release factory missing: %v", err)
	}
}

func TestGenerateReleaseRefusesExistingVersion(t *testing.T) {
	root := t.TempDir()
	spec := NewReleaseSpec("1.0.0", "demo_svc")
	if _, err := GenerateRelease(spec, root); err != nil {
		t.Fatalf("first release: %v", err)
	}
	if _, err := GenerateRelease(spec, root); err == nil {
		t.Fatal("expected error when release version already exists")
	}
}

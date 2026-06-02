package crossplane

import "testing"

func TestValidateRuntimeMode(t *testing.T) {
	cases := []string{RuntimeModeNone, RuntimeModeServerDryRun, RuntimeModeApplyDelete}
	for _, mode := range cases {
		if err := ValidateRuntimeMode(mode); err != nil {
			t.Fatalf("ValidateRuntimeMode(%q) error = %v", mode, err)
		}
	}
}

func TestValidateRuntimeModeInvalid(t *testing.T) {
	if err := ValidateRuntimeMode("dangerous-mode"); err == nil {
		t.Fatalf("expected invalid mode to return error")
	}
}

func TestValidateRuntimeProfile(t *testing.T) {
	cases := []string{RuntimeProfileNone, RuntimeProfileSmoke, RuntimeProfileLifecycle, RuntimeProfileCatalog, RuntimeProfileAPILifecycle, RuntimeProfileMatrix}
	for _, profile := range cases {
		if err := ValidateRuntimeProfile(profile); err != nil {
			t.Fatalf("ValidateRuntimeProfile(%q) error = %v", profile, err)
		}
	}
}

func TestValidateRuntimeProfileInvalid(t *testing.T) {
	if err := ValidateRuntimeProfile("unsafe"); err == nil {
		t.Fatalf("expected invalid profile to return error")
	}
}

func TestResolveRuntimeOptionsSmokeProfile(t *testing.T) {
	resolved, err := ResolveRuntimeOptions(RuntimeProfileSmoke, RuntimeOptions{Mode: RuntimeModeNone})
	if err != nil {
		t.Fatalf("ResolveRuntimeOptions(smoke) error = %v", err)
	}
	if resolved.Mode != RuntimeModeServerDryRun {
		t.Fatalf("expected server-dry-run mode, got %q", resolved.Mode)
	}
}

func TestResolveRuntimeOptionsLifecycleProfile(t *testing.T) {
	resolved, err := ResolveRuntimeOptions(RuntimeProfileLifecycle, RuntimeOptions{Mode: RuntimeModeNone})
	if err != nil {
		t.Fatalf("ResolveRuntimeOptions(lifecycle) error = %v", err)
	}
	if resolved.Mode != RuntimeModeApplyDelete {
		t.Fatalf("expected apply-delete mode, got %q", resolved.Mode)
	}
	if !resolved.Cleanup {
		t.Fatalf("expected lifecycle profile cleanup to be true")
	}
}

func TestResolveRuntimeOptionsProfileModeConflict(t *testing.T) {
	_, err := ResolveRuntimeOptions(RuntimeProfileSmoke, RuntimeOptions{Mode: RuntimeModeApplyDelete})
	if err == nil {
		t.Fatalf("expected profile/mode conflict error")
	}
}

func TestResolveRuntimeOptionsCatalogProfile(t *testing.T) {
	resolved, err := ResolveRuntimeOptions(RuntimeProfileCatalog, RuntimeOptions{Mode: RuntimeModeNone})
	if err != nil {
		t.Fatalf("ResolveRuntimeOptions(catalog) error = %v", err)
	}
	if resolved.Mode != RuntimeModeServerDryRun {
		t.Fatalf("expected server-dry-run mode, got %q", resolved.Mode)
	}
	if !resolved.IncludePrerequisites {
		t.Fatalf("expected catalog profile to include prerequisites")
	}
}

func TestResolveRuntimeOptionsAPILifecycleProfile(t *testing.T) {
	resolved, err := ResolveRuntimeOptions(RuntimeProfileAPILifecycle, RuntimeOptions{Mode: RuntimeModeNone})
	if err != nil {
		t.Fatalf("ResolveRuntimeOptions(api-lifecycle) error = %v", err)
	}
	if resolved.Mode != RuntimeModeApplyDelete {
		t.Fatalf("expected apply-delete mode, got %q", resolved.Mode)
	}
	if resolved.Timeout != "180s" {
		t.Fatalf("expected api-lifecycle timeout 180s, got %q", resolved.Timeout)
	}
}

func TestExpandRuntimeProfilesMatrix(t *testing.T) {
	profiles, err := ExpandRuntimeProfiles(RuntimeProfileMatrix)
	if err != nil {
		t.Fatalf("ExpandRuntimeProfiles(matrix) error = %v", err)
	}
	if len(profiles) != 3 {
		t.Fatalf("expected 3 matrix profiles, got %d", len(profiles))
	}
	if profiles[0] != RuntimeProfileSmoke || profiles[1] != RuntimeProfileCatalog || profiles[2] != RuntimeProfileAPILifecycle {
		t.Fatalf("unexpected matrix profile sequence: %#v", profiles)
	}
}

func TestResolveRuntimeOptionsMatrixRequiresExpansion(t *testing.T) {
	_, err := ResolveRuntimeOptions(RuntimeProfileMatrix, RuntimeOptions{Mode: RuntimeModeNone})
	if err == nil {
		t.Fatalf("expected matrix profile to require expansion")
	}
}

func TestSelectMatrixProfilesFromStop(t *testing.T) {
	all, err := ExpandRuntimeProfiles(RuntimeProfileMatrix)
	if err != nil {
		t.Fatalf("ExpandRuntimeProfiles(matrix) error = %v", err)
	}
	selected, err := SelectMatrixProfiles(all, RuntimeProfileCatalog, RuntimeProfileAPILifecycle)
	if err != nil {
		t.Fatalf("SelectMatrixProfiles() error = %v", err)
	}
	if len(selected) != 2 {
		t.Fatalf("expected 2 selected profiles, got %d", len(selected))
	}
	if selected[0] != RuntimeProfileCatalog || selected[1] != RuntimeProfileAPILifecycle {
		t.Fatalf("unexpected selected sequence: %#v", selected)
	}
}

func TestSelectMatrixProfilesOrderError(t *testing.T) {
	all, _ := ExpandRuntimeProfiles(RuntimeProfileMatrix)
	_, err := SelectMatrixProfiles(all, RuntimeProfileAPILifecycle, RuntimeProfileSmoke)
	if err == nil {
		t.Fatalf("expected order validation error")
	}
}

func TestSelectMatrixProfilesInvalidBoundary(t *testing.T) {
	all, _ := ExpandRuntimeProfiles(RuntimeProfileMatrix)
	_, err := SelectMatrixProfiles(all, "not-a-step", "")
	if err == nil {
		t.Fatalf("expected invalid from-step error")
	}
}

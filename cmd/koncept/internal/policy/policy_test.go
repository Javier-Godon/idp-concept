package policy

import (
	"strings"
	"testing"
	"time"
)

const goodManifest = `
apiVersion: apps/v1
kind: Deployment
metadata:
  name: good-app
  namespace: apps
  labels:
    app.kubernetes.io/part-of: erp
spec:
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/acme/app:1.2.3
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: "1"
            memory: 512Mi
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
`

const badManifest = `
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-app
spec:
  template:
    spec:
      hostNetwork: true
      containers:
      - name: app
        image: nginx
        securityContext:
          privileged: true
`

func countRule(findings []Finding, rule string) int {
	n := 0
	for _, f := range findings {
		if f.Rule == rule {
			n++
		}
	}
	return n
}

func TestCheckGoodManifestPasses(t *testing.T) {
	findings, err := Check(goodManifest, DefaultOptions())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(findings) != 0 {
		t.Fatalf("expected no findings, got %d: %+v", len(findings), findings)
	}
}

func TestCheckBadManifestFlagsViolations(t *testing.T) {
	findings, err := Check(badManifest, DefaultOptions())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	for _, rule := range []string{"no-host-network", "no-privileged", "no-latest-tag", "require-resources", "require-owner"} {
		if countRule(findings, rule) == 0 {
			t.Errorf("expected rule %q to fire", rule)
		}
	}
}

func TestImageTag(t *testing.T) {
	cases := map[string]string{
		"nginx":                    "",
		"nginx:latest":             "latest",
		"nginx:1.27":               "1.27",
		"registry.io:5000/app":     "",
		"registry.io:5000/app:2.0": "2.0",
		"app@sha256:abcd":          "abcd",
	}
	for image, want := range cases {
		if got := imageTag(image); got != want {
			t.Errorf("imageTag(%q) = %q, want %q", image, got, want)
		}
	}
}

const secretLiteralManifest = `
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-app
  namespace: apps
  labels:
    owner: team
spec:
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/acme/app:1.0.0
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits: {cpu: "1", memory: 256Mi}
        env:
        - name: DB_PASSWORD
          value: hunter2
        - name: API_TOKEN
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: token
        - name: LOG_LEVEL
          value: info
`

func TestSecretLiteralFlagged(t *testing.T) {
	findings, err := Check(secretLiteralManifest, DefaultOptions())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if countRule(findings, "no-secret-literals") != 1 {
		t.Fatalf("expected exactly one no-secret-literals finding, got %d: %+v",
			countRule(findings, "no-secret-literals"), findings)
	}
	for _, f := range findings {
		if f.Rule == "no-secret-literals" && f.Severity != SeverityError {
			t.Errorf("secret-literal should be an error, got %s", f.Severity)
		}
	}
}

func TestRequireNamespaceWarns(t *testing.T) {
	// badManifest declares no namespace.
	findings, err := Check(badManifest, DefaultOptions())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if countRule(findings, "require-namespace") == 0 {
		t.Error("expected require-namespace to fire on namespaced workload without namespace")
	}
}

func TestRequireNamespaceDisabled(t *testing.T) {
	opts := DefaultOptions()
	opts.RequireNamespace = false
	findings, _ := Check(badManifest, opts)
	if countRule(findings, "require-namespace") != 0 {
		t.Error("require-namespace should not fire when disabled")
	}
}

func TestRequireNetworkPolicyWarnsOncePerNamespace(t *testing.T) {
	// Two workloads in the same namespace, no NetworkPolicy -> exactly one warning.
	manifest := `
apiVersion: apps/v1
kind: Deployment
metadata:
  name: a
  namespace: apps
  labels: {owner: team}
spec:
  template:
    spec:
      containers:
      - name: a
        image: ghcr.io/acme/a:1.0.0
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits: {cpu: "1", memory: 256Mi}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: b
  namespace: apps
  labels: {owner: team}
spec:
  template:
    spec:
      containers:
      - name: b
        image: ghcr.io/acme/b:1.0.0
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits: {cpu: "1", memory: 256Mi}
`
	findings, err := Check(manifest, DefaultOptions())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got := countRule(findings, "require-network-policy"); got != 1 {
		t.Fatalf("expected exactly one require-network-policy finding, got %d: %+v", got, findings)
	}
	for _, f := range findings {
		if f.Rule == "require-network-policy" && f.Severity != SeverityWarning {
			t.Errorf("require-network-policy should be a warning, got %s", f.Severity)
		}
	}
}

func TestRequireNetworkPolicySatisfied(t *testing.T) {
	findings, err := Check(goodManifest, DefaultOptions())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if countRule(findings, "require-network-policy") != 0 {
		t.Errorf("require-network-policy should not fire when a NetworkPolicy covers the namespace")
	}
}

func TestRequireNetworkPolicyDisabled(t *testing.T) {
	opts := DefaultOptions()
	opts.RequireNetworkPolicy = false
	manifest := `
apiVersion: apps/v1
kind: Deployment
metadata:
  name: a
  namespace: apps
  labels: {owner: team}
spec:
  template:
    spec:
      containers:
      - name: a
        image: ghcr.io/acme/a:1.0.0
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits: {cpu: "1", memory: 256Mi}
`
	findings, _ := Check(manifest, opts)
	if countRule(findings, "require-network-policy") != 0 {
		t.Error("require-network-policy should not fire when disabled")
	}
}

func TestApplyExemptionsFiltersMatchingFinding(t *testing.T) {
	findings, err := Check(secretLiteralManifest, DefaultOptions())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	filtered, err := ApplyExemptions(findings, []Exemption{{
		Rule:      "no-secret-literals",
		Kind:      "Deployment",
		Namespace: "apps",
		Name:      "secret-app",
		Owner:     "security",
		Reason:    "legacy app migration tracked in PLATFORM-123",
		ExpiresOn: "2026-12-31",
	}}, time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("unexpected exemption error: %v", err)
	}
	if countRule(filtered, "no-secret-literals") != 0 {
		t.Fatalf("expected no-secret-literals to be exempted, got %+v", filtered)
	}
}

func TestApplyExemptionsRejectsExpired(t *testing.T) {
	_, err := ApplyExemptions([]Finding{{
		Rule:      "require-owner",
		Kind:      "Deployment",
		Namespace: "apps",
		Name:      "app",
	}}, []Exemption{{
		Rule:      "require-owner",
		Kind:      "Deployment",
		Namespace: "apps",
		Name:      "app",
		Owner:     "platform",
		Reason:    "temporary migration",
		ExpiresOn: "2026-05-30",
	}}, time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC))
	if err == nil || !strings.Contains(err.Error(), "expired") {
		t.Fatalf("expected expired exemption error, got %v", err)
	}
}

func TestApplyExemptionsRejectsStale(t *testing.T) {
	_, err := ApplyExemptions([]Finding{{
		Rule:      "require-owner",
		Kind:      "Deployment",
		Namespace: "apps",
		Name:      "app",
	}}, []Exemption{{
		Rule:      "require-owner",
		Kind:      "Deployment",
		Namespace: "apps",
		Name:      "other-app",
		Owner:     "platform",
		Reason:    "temporary migration",
		ExpiresOn: "2026-12-31",
	}}, time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC))
	if err == nil || !strings.Contains(err.Error(), "stale") {
		t.Fatalf("expected stale exemption error, got %v", err)
	}
}

func TestApplyExemptionsRequiresTarget(t *testing.T) {
	_, err := ApplyExemptions([]Finding{{
		Rule: "require-owner",
		Kind: "Deployment",
	}}, []Exemption{{
		Rule:      "require-owner",
		Owner:     "platform",
		Reason:    "temporary migration",
		ExpiresOn: "2026-12-31",
	}}, time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC))
	if err == nil || !strings.Contains(err.Error(), "must set kind") {
		t.Fatalf("expected narrow target error, got %v", err)
	}
}

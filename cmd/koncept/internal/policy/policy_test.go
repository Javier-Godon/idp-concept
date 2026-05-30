package policy

import "testing"

const goodManifest = `
apiVersion: apps/v1
kind: Deployment
metadata:
  name: good-app
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

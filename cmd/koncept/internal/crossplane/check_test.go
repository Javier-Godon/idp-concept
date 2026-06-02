package crossplane

import "testing"

const sampleRendered = `xrd:
  apiVersion: apiextensions.crossplane.io/v2
  kind: CompositeResourceDefinition
  metadata:
    name: xapps.koncept.bluesolution.es
composition:
  apiVersion: apiextensions.crossplane.io/v1
  kind: Composition
  spec:
    mode: Pipeline
    pipeline:
      - step: render-manifests
      - step: sequence-creation
      - step: automatically-detect-readiness
xr:
  apiVersion: koncept.bluesolution.es/v1alpha1
  kind: XApp
  metadata:
    name: app-workload
prerequisites:
  - apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-kubernetes
    spec:
      package: xpkg.upbound.io/upbound/provider-kubernetes:v1
  - apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-helm
    spec:
      package: xpkg.upbound.io/upbound/provider-helm:v1
  - apiVersion: pkg.crossplane.io/v1beta1
    kind: Function
    metadata:
      name: function-patch-and-transform
    spec:
      package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.9.0
  - apiVersion: pkg.crossplane.io/v1beta1
    kind: Function
    metadata:
      name: function-sequencer
    spec:
      package: xpkg.upbound.io/crossplane-contrib/function-sequencer:v0.2.3
  - apiVersion: pkg.crossplane.io/v1beta1
    kind: Function
    metadata:
      name: function-auto-ready
    spec:
      package: xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.5.0
`

func TestValidateRenderedOutputStaticOnly(t *testing.T) {
	report, err := ValidateRenderedOutput(sampleRendered, false, false)
	if err != nil {
		t.Fatalf("ValidateRenderedOutput() error = %v", err)
	}
	if !report.StaticChecksPassed {
		t.Fatalf("expected static checks to pass")
	}
	if len(report.ProviderPackages) != 2 {
		t.Fatalf("expected 2 provider packages, got %d", len(report.ProviderPackages))
	}
	if len(report.FunctionPackages) != 3 {
		t.Fatalf("expected 3 function packages, got %d", len(report.FunctionPackages))
	}
}

func TestValidateRenderedOutputRequiresPinnedPackages(t *testing.T) {
	broken := `xrd: {kind: CompositeResourceDefinition}
composition:
  kind: Composition
  spec:
    mode: Pipeline
    pipeline:
      - step: render-manifests
      - step: automatically-detect-readiness
xr: {apiVersion: koncept.bluesolution.es/v1alpha1}
prerequisites:
  - kind: Provider
    spec: {package: xpkg.upbound.io/upbound/provider-kubernetes:latest}
  - kind: Provider
    spec: {package: xpkg.upbound.io/upbound/provider-helm:v1}
  - kind: Function
    spec: {package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.9.0}
  - kind: Function
    spec: {package: xpkg.upbound.io/crossplane-contrib/function-sequencer:v0.2.3}
  - kind: Function
    spec: {package: xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.5.0}
`
	_, err := ValidateRenderedOutput(broken, false, false)
	if err == nil {
		t.Fatalf("expected error for unpinned latest package")
	}
}

func TestValidateRenderedOutputRequiresPipelineSteps(t *testing.T) {
	broken := `xrd: {kind: CompositeResourceDefinition}
composition:
  kind: Composition
  spec:
    mode: Pipeline
    pipeline:
      - step: render-manifests
xr: {apiVersion: koncept.bluesolution.es/v1alpha1}
prerequisites:
  - kind: Provider
    spec: {package: xpkg.upbound.io/upbound/provider-kubernetes:v1}
  - kind: Provider
    spec: {package: xpkg.upbound.io/upbound/provider-helm:v1}
  - kind: Function
    spec: {package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.9.0}
  - kind: Function
    spec: {package: xpkg.upbound.io/crossplane-contrib/function-sequencer:v0.2.3}
  - kind: Function
    spec: {package: xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.5.0}
`
	_, err := ValidateRenderedOutput(broken, false, false)
	if err == nil {
		t.Fatalf("expected error for missing auto-ready step")
	}
}

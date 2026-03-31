"""
Test: can KCL conditionally render based on option("output")?
Run: kcl run test_to_delete/render_test.k -D output=yaml
      kcl run test_to_delete/render_test.k -D output=argocd
"""
import manifests

_output = option("output", default="yaml")

_yaml_data = [
    {apiVersion = "v1", kind = "ConfigMap", metadata = {name = "yaml-test"}, data = {key = "value"}}
]

_argocd_data = [
    {apiVersion = "argoproj.io/v1alpha1", kind = "Application", metadata = {name = "argocd-test"}}
]

if _output == "yaml":
    manifests.yaml_stream(_yaml_data)

if _output == "argocd":
    manifests.yaml_stream(_argocd_data)

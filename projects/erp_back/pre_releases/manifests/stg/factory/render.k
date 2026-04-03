"""
Generic multi-format renderer — uses option("output") to render different formats.
This file is designed to be identical in every factory directory.
It imports factory_seed.k from the same directory using relative import.

Factory Seed Contract — factory_seed.k MUST export these variables:
    _stack: RenderStack          — The full stack for rendering
    _project_name: str           — Project name (e.g., "ERP Back")
    _git_repo_url: str           — Git repository URL for ArgoCD
    _manifest_path: str          — Output path for manifest references

Usage:
    kcl run render.k                       # defaults to yaml
    kcl run render.k -D output=yaml        # plain K8s YAML
    kcl run render.k -D output=argocd      # ArgoCD Application CRDs
    kcl run render.k -D output=helmfile    # helmfile.yaml
    kcl run render.k -D output=helm        # Chart.yaml + values.yaml per component
    kcl run render.k -D output=kustomize   # kustomization.yaml + resource list
    kcl run render.k -D output=timoni      # Timoni CUE module structure
    kcl run render.k -D output=crossplane  # Crossplane XRD + Composition + XR
    kcl run render.k -D output=backstage   # Backstage catalog-info.yaml entities
"""
import manifests
import framework.procedures.kcl_to_yaml as yaml_proc
import framework.procedures.kcl_to_argocd as argocd_proc
import framework.procedures.kcl_to_helm as helm_proc
import framework.procedures.kcl_to_helmfile as helmfile_proc
import framework.procedures.kcl_to_kustomize as kustomize_proc
import framework.procedures.kcl_to_timoni as timoni_proc
import framework.procedures.kcl_to_crossplane as crossplane_proc
import framework.procedures.kcl_to_backstage as backstage_proc
import .factory_seed as seed

_output = option("output", default="yaml")

# --- Plain Kubernetes YAML (for ArgoCD/GitOps) ---
if _output == "yaml":
    yaml_proc.yaml_stream_stack(seed._stack)

# --- ArgoCD Application CRDs ---
if _output == "argocd":
    _argocd_apps = argocd_proc.generate_applications_from_stack(
        seed._stack
        seed._project_name
        seed._git_repo_url
        "HEAD"
        seed._manifest_path
    )
    manifests.yaml_stream(_argocd_apps)

# --- Helmfile (helmfile.yaml with per-component releases) ---
if _output == "helmfile":
    _helmfile = helmfile_proc.generate_helmfile(
        seed._stack.components
        seed._stack.accessories
        "./charts"
    )
    manifests.yaml_stream([_helmfile])

# --- Helm chart data (Chart.yaml + values.yaml per component) ---
if _output == "helm":
    _charts = helm_proc.generate_charts_from_stack(seed._stack)
    manifests.yaml_stream(_charts)

# --- Kustomize (kustomization.yaml + resource references) ---
if _output == "kustomize":
    _kustomization = kustomize_proc.generate_kustomization_from_stack(
        seed._stack.components
        seed._stack.accessories
        seed._stack.k8snamespaces
        seed._project_name
        "1.0.0"
    )
    manifests.yaml_stream([_kustomization])

# --- Timoni (CUE module structure) ---
if _output == "timoni":
    _timoni_module = timoni_proc.generate_timoni_module_from_stack(
        seed._stack.components
        seed._stack.accessories
        seed._stack.k8snamespaces
        seed._project_name
        "1.0.0"
    )
    manifests.yaml_stream([_timoni_module])

# --- Crossplane (XRD + Composition + XR + prerequisites) ---
if _output == "crossplane":
    _crossplane = crossplane_proc.generate_crossplane_from_stack(
        seed._stack.components
        seed._stack.accessories
        seed._stack.k8snamespaces
        seed._project_name
        "1.0.0"
    )
    manifests.yaml_stream([_crossplane])

# --- Backstage (catalog-info.yaml entities) ---
if _output == "backstage":
    _backstage = backstage_proc.generate_catalog_from_stack(
        seed._stack.components
        seed._stack.accessories
        seed._stack.k8snamespaces
        seed._project_name
        "1.0.0"
        "platform-team"
        "production"
        seed._git_repo_url
        "dir:docs/"
    )
    manifests.yaml_stream([_backstage])

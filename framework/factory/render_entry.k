"""
Shared render entrypoint helpers for factory render wrappers.

This module centralizes output rendering logic so project factories can keep
minimal `render.k` files that only pass local `factory_seed` context.
"""

import manifests
import procedures.kcl_to_yaml as yaml_proc
import procedures.kcl_to_argocd as argocd_proc
import procedures.kcl_to_helm as helm_proc
import procedures.kcl_to_helmfile as helmfile_proc
import procedures.kcl_to_kusion as kusion_proc
import procedures.kcl_to_kustomize as kustomize_proc
import procedures.kcl_to_timoni as timoni_proc
import procedures.kcl_to_crossplane as crossplane_proc
import procedures.kcl_to_backstage as backstage_proc

render_from_seed = lambda stack: any, project_name: str, git_repo_url: str, manifest_path: str, output: str -> any {
    if output == "yaml":
        yaml_proc.yaml_stream_stack(stack)

    if output == "argocd":
        _argocd_apps = argocd_proc.generate_applications_from_stack(stack, project_name, git_repo_url, "HEAD", manifest_path)
        manifests.yaml_stream(_argocd_apps)

    if output == "helmfile":
        _helmfile = helmfile_proc.generate_helmfile_from_stack(stack, "./charts")
        manifests.yaml_stream([_helmfile])

    if output == "helm":
        _charts = helm_proc.generate_charts_from_stack(stack)
        manifests.yaml_stream(_charts)

    if output == "kusion":
        _kusion_resources = kusion_proc.kusion_spec_stream_stack(stack)
        manifests.yaml_stream(_kusion_resources)

    if output == "kustomize":
        _kustomization = kustomize_proc.generate_kustomization_from_stack(stack.components, stack.accessories, stack.k8snamespaces, project_name, "1.0.0")
        manifests.yaml_stream([_kustomization])

    if output == "timoni":
        _timoni_module = timoni_proc.generate_timoni_module_from_stack(stack.components, stack.accessories, stack.k8snamespaces, project_name, "1.0.0")
        manifests.yaml_stream([_timoni_module])

    if output == "crossplane":
        _crossplane = crossplane_proc.generate_crossplane_from_stack(stack.components, stack.accessories, stack.k8snamespaces, project_name, "1.0.0")
        manifests.yaml_stream([_crossplane])

    if output == "backstage":
        _backstage = backstage_proc.generate_catalog_from_stack(stack.components, stack.accessories, stack.k8snamespaces, project_name, "1.0.0", "platform-team", "production", git_repo_url, "dir:docs/", stack.metadata)
        manifests.yaml_stream([_backstage])

    Undefined
}

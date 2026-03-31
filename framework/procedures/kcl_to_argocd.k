"""
ArgoCD generation — produces Application and AppProject manifests from stack structures.
Generates plain dicts (not ArgoCD schema types) to avoid cross-package dependency on custom/argocd/models.
Project-level builders can use these directly or use the typed Application schema for validation.
"""

_ARGOCD_API_VERSION = "argoproj.io/v1alpha1"
_ARGOCD_NAMESPACE = "argocd"
_K8S_API_SERVER = "https://kubernetes.default.svc"

generate_application = lambda comp: any, project_name: str, repo_url: str, target_revision: str, manifest_path: str, destination_namespace: str -> {str:} {
    """Generate an ArgoCD Application manifest for a single component."""
    {
        apiVersion = _ARGOCD_API_VERSION
        kind = "Application"
        metadata = {
            name = comp.name
            namespace = _ARGOCD_NAMESPACE
        }
        spec = {
            project = project_name
            source = {
                repoURL = repo_url
                targetRevision = target_revision
                path = manifest_path
            }
            destination = {
                server = _K8S_API_SERVER
                namespace = destination_namespace
            }
        }
    }
}

generate_applications_from_stack = lambda input_stack: any, project_name: str, repo_url: str, target_revision: str, manifest_path: str -> [{str:}] {
    """Generate ArgoCD Application manifests for all components in a stack."""
    _comps = input_stack.components if input_stack.components else []
    [
        generate_application(comp, project_name, repo_url, target_revision, manifest_path, comp.namespace)
        for comp in _comps
    ]
}

generate_app_project = lambda name: str, project_name: str, source_repos: [str], destination_namespaces: [str] -> {str:} {
    """Generate an ArgoCD AppProject manifest."""
    {
        apiVersion = _ARGOCD_API_VERSION
        kind = "AppProject"
        metadata = {
            name = name
            namespace = _ARGOCD_NAMESPACE
        }
        spec = {
            sourceRepos = source_repos
            destinations = [
                {
                    server = _K8S_API_SERVER
                    namespace = ns
                }
                for ns in destination_namespaces
            ]
            clusterResourceWhitelist = [
                { group = "", kind = "Namespace" }
            ]
        }
    }
}

"""
ArgoCD application builder — generates ArgoCD Application CRD.
"""
import erp_back.pre_releases.gitops.dev.factory.factory_seed
import framework.custom.argocd.models.v1alpha1.argoproj_io_v1alpha1_application as application

_application_name = factory_seed._erp_api_stack.components[0].name
_project_name = factory_seed._pre_release_development_dev_cluster.project.name

application.Application {
    metadata = {
        name = _application_name
        namespace = "argocd"
    }
    spec = {
        project = _project_name
        source = {
            repoURL = "https://github.com/Javier-Godon/idp-concept"
            targetRevision = "HEAD"
            path = "projects/erp_back/pre_releases/gitops/dev/output/kubernetes_manifests.yaml"
        }
        destination = {
            server = "https://kubernetes.default.svc"
            namespace = "erp-apps"
        }
    }
}

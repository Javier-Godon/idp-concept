"""
Kubernetes manifests builder — generates plain YAML for GitOps/ArgoCD.
"""
import framework.procedures.kcl_to_yaml
import erp_back.pre_releases.gitops.dev.factory.factory_seed

kcl_to_yaml.yaml_stream_stack(factory_seed._erp_back_development_dev_cluster_stack)

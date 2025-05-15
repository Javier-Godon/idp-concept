import video_streaming.stacks.development.stack_def as stack
import framework.models.release
import framework.procedures.kcl_to_yaml
import video_streaming.kernel.project_def
import video_streaming.pre_releases.configurations_dev as core_configurations_dev
import framework.models.gitops.gitopsstack
import framework.procedures.helper

_release_configurations = core_configurations_dev._pre_release_configurations_dev_cluster
_stack = core_configurations_dev._stack

_kafka_video_consumer_mongodb_python_development_dev_cluster_stack = gitopsstack.GitOpsStack {
    instanceConfigurations = _stack.instanceConfigurations
    k8snamespaces = helper.extract_models_by_name_from_list(_stack.k8snamespaces, "apps")
    components = helper.extract_models_by_name_from_list(_stack.components, "kafka_video_consumer_mongodb_python")
}

_pre_release_development_dev_cluster = release.Release {
    name = "pre_release_development_dev_cluster"
    version = "1.0.0"
    project = core_configurations_dev._project.instance
    tenant = core_configurations_dev._tenant.instance
    site = core_configurations_dev._site.instance
    profile = core_configurations_dev._profile.instance
    stack = _stack
}

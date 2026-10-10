import framework.models.project
import platform.kernel.configurations

platform_project = project.Project {
    name = "platform"
    description = "Platform services: shared API gateway and platform tool routes"
    configurations = configurations._platform_kernel_configurations
}

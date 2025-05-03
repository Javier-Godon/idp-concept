import configs.models.kernel_config

schema ProjectInstance:
    name: str
    description: str
    configurations: kernel_config.KernelConfig

schema Project:
    instance: ProjectInstance = ProjectInstance {
        name = name
        description = description
        configurations = configurations
    }
    name: str
    description: str
    configurations: kernel_config.KernelConfig


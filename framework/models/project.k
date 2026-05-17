"""
A project has a name and a description and the rest of configurations are defined in its the kernel.So, the core of this project is configured
in the kernel folder. So in some sense kernel is the same as project and contains all the configurations apart from name and some descriptions
"""
import models.metadata as meta

schema ProjectInstance:
    name: str
    description: str
    metadata?: meta.Metadata
    # framework-generic: accepts any project config schema
    configurations: any

schema Project:
    instance: ProjectInstance = ProjectInstance {
        name = name
        description = description
        metadata = metadata
        configurations = configurations
    }
    name: str
    description: str
    metadata?: meta.Metadata
    # framework-generic: accepts any project config schema
    configurations: any


"""
nexus project-specific configuration schema.
Extends BaseConfigurations with project-specific fields.
"""

import framework.models.configurations as base

schema NexusConfigurations(base.BaseConfigurations):
    nexusHostname?: str
    nexusPath?: str
    nexusStorageSize?: str

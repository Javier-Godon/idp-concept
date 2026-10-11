"""
Shared nexus stack template.
Profile-specific folders override only the values that differ.
"""

import framework.models.stack
import framework.models.compatibility as compat
import framework.assembly.helpers as asm
import nexus.modules.appops.nexus_repository.nexus_repository_module_def as nexus_repository
# koncept:imports:end

schema NexusStack(stack.Stack):
    compatibility = compat.FrameworkCompatibility {
        version = "dev"
        versionConstraint = ">=0.1.0 <1.0.0"
        supportTier = "tier-1"
        source = "local"
        supportWindow = "until next minor framework release"
    }

    _apps_namespace = asm.create_namespace(instanceConfigurations.appsNamespace, instanceConfigurations)

    k8snamespaces = [_apps_namespace]

    _nexus = nexus_repository.NexusRepositoryModule {
        name = "nexus"
        namespace = _apps_namespace.name
        asset = {
            image = "sonatype/nexus3"
            version = "3.96.4"
        }
        configurations = instanceConfigurations
        dependsOn = [_apps_namespace]
    }.instance

    # koncept:modules:end

    components = [_nexus]  # koncept:components
    accessories = []  # koncept:accessories

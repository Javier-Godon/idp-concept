"""
Nexus Repository module — Sonatype Nexus 3 with a persistent /nexus-data volume, published on the
platform gateway under a sub-path of the shared hostname (e.g. bluesolution.es/nexus).
"""
import framework.templates.nexus.v1_0_0.nexus as nexus

schema NexusRepositoryModule(nexus.NexusModule):
    storageSize = configurations.nexusStorageSize
    contextPath = configurations.nexusPath
    # Uploads of large artifacts must not hit the gateway's default request timeout.
    route = {
        hostnames = [configurations.nexusHostname]
        path = configurations.nexusPath
        timeout = "0s"
    }

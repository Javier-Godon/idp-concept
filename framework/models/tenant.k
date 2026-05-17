import models.metadata as meta

schema TenantInstance:
    name: str
    description: str
    metadata?: meta.Metadata
    # framework-generic: accepts any project config schema
    configurations: any

schema Tenant:
    instance: TenantInstance = TenantInstance {
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


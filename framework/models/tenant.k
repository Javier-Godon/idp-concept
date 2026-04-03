schema TenantInstance:
    name: str
    description: str
    # framework-generic: accepts any project config schema
    configurations: any

schema Tenant:
    instance: TenantInstance = TenantInstance {
        name = name
        description = description
        configurations = configurations
    }
    name: str
    description: str
    # framework-generic: accepts any project config schema
    configurations: any


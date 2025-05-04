schema TenantInstance:
    name: str
    description: str
    configurations: any

schema Tenant:
    instance: TenantInstance = TenantInstance {
        name = name
        description = description
        configurations = configurations
    }
    name: str
    description: str
    configurations: any


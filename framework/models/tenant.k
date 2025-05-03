schema TenantInstance:
    name: str
    description: str

schema Tenant:
    instance: TenantInstance = TenantInstance {
        name = name
        description = description
    }
    name: str
    description: str


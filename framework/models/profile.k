"""
Generic term to describe a "behevioral or deployment mode" of each component, across environments (dev, staging, pre (version v.v.v), pro (version v.v.v)...)
It refers to the definition of the component and not the environment (site) where that component is going to be deployed.
For example. We can deploy the same dev version (profile) of a microservice in a concrete kubernetes cluster owned by the company (site) or in an environment owned by a tenant.
"""
import models.metadata as meta

schema ProfileInstance:
    name: str
    metadata?: meta.Metadata
    configurations: any

schema Profile:
    instance: ProfileInstance = ProfileInstance {
        name = name
        metadata = metadata
        configurations = configurations
    }
    name: str
    metadata?: meta.Metadata
    configurations: any


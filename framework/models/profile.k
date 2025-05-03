"""
Generic term to describe a "behevioral or deployment mode" of each component, across environments (dev, staging, pre (version v.v.v), pro (version v.v.v)...)
It refers to the definition of the component and not the environment (site) where that component is going to be deployed.
For example. We can deploy the same dev version (profile) of a microservice in a concrete kubernetes cluster owned by the company (site) or in an environment owned by a tenant.
"""
import configs.models.profile_config as profile_config

schema ProfileInstance:
    name: str
    configurations: profile_config.ProfileConfig

schema Profile:
    instance: ProfileInstance = ProfileInstance {
        name = name
        configurations = configurations
    }
    name: str
    configurations: profile_config.ProfileConfig


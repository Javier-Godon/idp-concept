"""
Framework compatibility metadata for stacks and releases.

The model is intentionally descriptive rather than enforcing semantic-version
ranges in KCL. Tooling and CI can read the same fields and decide when to warn
or fail as the framework distribution model matures.
"""

schema FrameworkCompatibility:
    framework: str = "idp-concept/framework"
    source?: str = "local"
    version?: str
    versionConstraint?: str
    testedVersions?: [str]
    supportTier?: str
    supportWindow?: str
    deprecatedAfter?: str
    migrationGuide?: str
    notes?: str

    check:
        len(framework) > 0, "framework compatibility name must not be empty"
        source == Undefined or source in ["local", "git", "oci", "registry"], "framework source must be local, git, oci, or registry"
        version == Undefined or len(version) > 0, "framework version must not be empty"
        versionConstraint == Undefined or len(versionConstraint) > 0, "framework version constraint must not be empty"
        supportTier == Undefined or len(supportTier) > 0, "support tier must not be empty"


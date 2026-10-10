"""platform development stack — only profile-specific overrides live here."""

import platform.stacks.platform_stack as common

schema Stack(common.PlatformStack):
    # Override image tags or sizing for development here.

schema PlatformDevelopmentStack(Stack):
    # Backward-compatible alias for existing imports.

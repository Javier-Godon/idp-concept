"""nexus development stack — only profile-specific overrides live here."""

import nexus.stacks.nexus_stack as common

schema Stack(common.NexusStack):
    # Override image tags or sizing for development here.

schema NexusDevelopmentStack(Stack):
    # Backward-compatible alias for existing imports.

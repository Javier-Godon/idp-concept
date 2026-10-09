"""erp development stack — only profile-specific overrides live here."""

import erp.stacks.erp_stack as common

schema Stack(common.ErpStack):
    # Override image tags or sizing for development here.

schema ErpDevelopmentStack(Stack):
    # Backward-compatible alias for existing imports.

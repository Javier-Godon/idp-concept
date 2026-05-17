"""ERP Back development stack — only profile-specific overrides live here."""

import erp_back.stacks.erp_back_stack as common

schema Stack(common.ErpBackStack):
    # Override image tags here when development diverges from shared defaults.

schema ErpBackDevelopmentStack(Stack):
    # Backward-compatible alias for existing imports.

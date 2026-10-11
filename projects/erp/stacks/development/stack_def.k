"""erp development stack — only profile-specific overrides live here."""

import erp.stacks.erp_stack as common
import erp.stacks.erp_apps_stack as apps

schema Stack(common.ErpStack):
    # Override image tags or sizing for development here.

schema ErpDevelopmentStack(Stack):
    # Backward-compatible alias for existing imports.

schema AppsStack(apps.ErpAppsStack):
    # Application workloads (dev_apps pre-release). Override image tags for development here.

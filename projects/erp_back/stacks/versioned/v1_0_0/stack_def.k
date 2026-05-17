"""ERP Back v1.0.0 release stack — only version-specific pins live here."""

import erp_back.stacks.erp_back_stack as common

schema Stack(common.ErpBackStack):
    erpApiVersion = "1.0.0"
    postgresVersion = "16.4-alpine"

schema ErpBackV1_0_0Stack(Stack):
    # Backward-compatible alias for existing imports.


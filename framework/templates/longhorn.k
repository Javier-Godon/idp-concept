"""Backward-compatible Longhorn template wrapper.

The implementation lives in `templates.longhorn.main`. Keep this root module thin so
existing imports such as `import templates.longhorn as longhorn` continue to work
without duplicating template implementation code.
"""

import templates.longhorn.main as longhorn_compat

LonghornSpec = longhorn_compat.LonghornSpec
build_longhorn_release = longhorn_compat.build_longhorn_release
build_longhorn_storage_class = longhorn_compat.build_longhorn_storage_class
build_longhorn_resources = longhorn_compat.build_longhorn_resources
LonghornModule = longhorn_compat.LonghornModule

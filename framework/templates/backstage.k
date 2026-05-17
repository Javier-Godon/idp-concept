"""Backward-compatible Backstage template wrapper.

The implementation lives in `templates.backstage.main`. Keep this root module thin so
existing imports such as `import templates.backstage as backstage` continue to work
without duplicating template implementation code.
"""

import templates.backstage.main as backstage_compat

BackstageHelmSpec = backstage_compat.BackstageHelmSpec
build_backstage_release = backstage_compat.build_backstage_release

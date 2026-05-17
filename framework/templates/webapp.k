"""Backward-compatible Webapp template wrapper.

The implementation lives in `templates.webapp.main`. Keep this root module thin so
existing imports such as `import templates.webapp as webapp` continue to work
without duplicating template implementation code.
"""

import templates.webapp.main as webapp_compat

WebAppModule = webapp_compat.WebAppModule

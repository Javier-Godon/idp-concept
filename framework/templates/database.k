"""Backward-compatible Database template wrapper.

The implementation lives in `templates.database.main`. Keep this root module thin so
existing imports such as `import templates.database as database` continue to work
without duplicating template implementation code.
"""

import templates.database.main as database_compat

SingleDatabaseModule = database_compat.SingleDatabaseModule

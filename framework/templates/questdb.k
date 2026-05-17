"""Backward-compatible Questdb template wrapper.

The implementation lives in `templates.questdb.main`. Keep this root module thin so
existing imports such as `import templates.questdb as questdb` continue to work
without duplicating template implementation code.
"""

import templates.questdb.main as questdb_compat

QuestDBSpec = questdb_compat.QuestDBSpec
build_questdb_release = questdb_compat.build_questdb_release

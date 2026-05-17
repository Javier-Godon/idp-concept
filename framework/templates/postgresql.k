"""Backward-compatible Postgresql template wrapper.

The implementation lives in `templates.postgresql.main`. Keep this root module thin so
existing imports such as `import templates.postgresql as postgresql` continue to work
without duplicating template implementation code.
"""

import templates.postgresql.main as postgresql_compat

CNPGClusterSpec = postgresql_compat.CNPGClusterSpec
CNPGScheduledBackupSpec = postgresql_compat.CNPGScheduledBackupSpec
CNPGPoolerSpec = postgresql_compat.CNPGPoolerSpec
build_cnpg_cluster = postgresql_compat.build_cnpg_cluster
build_scheduled_backup = postgresql_compat.build_scheduled_backup
build_pooler = postgresql_compat.build_pooler
PostgreSQLClusterModule = postgresql_compat.PostgreSQLClusterModule

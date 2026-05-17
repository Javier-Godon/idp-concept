"""Backward-compatible Vault template wrapper.

The implementation lives in `templates.vault.main`. Keep this root module thin so
existing imports such as `import templates.vault as vault` continue to work
without duplicating template implementation code.
"""

import templates.vault.main as vault_compat

VaultConnectionSpec = vault_compat.VaultConnectionSpec
build_vault_connection = vault_compat.build_vault_connection
VaultAuthSpec = vault_compat.VaultAuthSpec
build_vault_auth = vault_compat.build_vault_auth
VaultStaticSecretSpec = vault_compat.VaultStaticSecretSpec
build_vault_static_secret = vault_compat.build_vault_static_secret

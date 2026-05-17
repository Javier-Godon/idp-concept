"""Backward-compatible Valkey template wrapper.

The implementation lives in `templates.valkey.main`. Keep this root module thin so
existing imports such as `import templates.valkey as valkey` continue to work
without duplicating template implementation code.
"""

import templates.valkey.main as valkey_compat

ValkeySpec = valkey_compat.ValkeySpec
build_valkey_release = valkey_compat.build_valkey_release
ValkeyModule = valkey_compat.ValkeyModule

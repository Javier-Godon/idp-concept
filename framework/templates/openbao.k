"""Backward-compatible Openbao template wrapper.

The implementation lives in `templates.openbao.main`. Keep this root module thin so
existing imports such as `import templates.openbao as openbao` continue to work
without duplicating template implementation code.
"""

import templates.openbao.main as openbao_compat

OpenBaoSpec = openbao_compat.OpenBaoSpec
build_openbao_release = openbao_compat.build_openbao_release
OpenBaoModule = openbao_compat.OpenBaoModule

"""Backward-compatible Minio template wrapper.

The implementation lives in `templates.minio.main`. Keep this root module thin so
existing imports such as `import templates.minio as minio` continue to work
without duplicating template implementation code.
"""

import templates.minio.main as minio_compat

MinIOTenantSpec = minio_compat.MinIOTenantSpec
build_minio_tenant = minio_compat.build_minio_tenant
MinIOHelmSpec = minio_compat.MinIOHelmSpec
build_minio_helm = minio_compat.build_minio_helm

"""
Acceptance fixture: optional data admin UIs through the IDP render path.
"""
import ._helpers as h
import templates.admin.v1_0_0.data_admin as admin

_namespace = "idp-acceptance-data-admin"
_resources = admin.build_pgadmin_resources(admin.PgAdminSpec {
    name = "acceptance-pgadmin"
    namespace = _namespace
    footprint = "local"
    passwordSecretName = "pgadmin-admin-password"
}) + admin.build_mongo_express_resources(admin.MongoExpressSpec {
    name = "acceptance-mongo-express"
    namespace = _namespace
    footprint = "local"
    mongoHost = "acceptance-mongodb"
    basicAuthEnabled = False
}) + admin.build_redis_insight_resources(admin.RedisInsightSpec {
    name = "acceptance-redisinsight"
    namespace = _namespace
    footprint = "local"
    targetHost = "acceptance-valkey"
})

_module = h.wrap_component("acceptance-data-admin", _namespace, _resources, "1.0.0")
h.render_component(_namespace, _module)

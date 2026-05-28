import runtime
import templates.admin.v1_0_0.data_admin as admin

_pgadmin_secret = "pgadmin-secret"

test_pgadmin_resources = lambda {
    _resources = admin.build_pgadmin_resources(admin.PgAdminSpec {
        name = "pgadmin"
        namespace = "data"
        passwordSecretName = _pgadmin_secret
        footprint = "local"
    })
    assert len(_resources) == 2
    assert _resources[0].kind == "Deployment"
    assert _resources[1].kind == "Service"
    assert _resources[0].spec.template.spec.containers[0].env[1].valueFrom.secretKeyRef.name == _pgadmin_secret
}

test_mongo_express_requires_production_credentials = lambda {
    _err = runtime.catch(lambda {
        admin.MongoExpressSpec {
            name = "mongo-ui"
            namespace = "data"
            footprint = "production"
            mongoHost = "mongo"
        }
    })
    assert _err != Undefined
}

test_redis_insight_resources = lambda {
    _resources = admin.build_redis_insight_resources(admin.RedisInsightSpec {
        name = "valkey-admin"
        namespace = "data"
        targetHost = "valkey-primary"
        footprint = "development"
    })
    assert _resources[0].spec.template.spec.containers[0].image == "redis/redisinsight:2.60"
    assert _resources[1].spec.ports[0].port == 5540
}

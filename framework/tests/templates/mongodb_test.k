"""
MongoDB Community Template Tests.

Tests the build_mongodb_community lambda for the
MongoDB Community Kubernetes Operator (mongodbcommunity.mongodb.com/v1).
"""
import templates.mongodb as mongo
import runtime

# === Test: build_mongodb_community generates correct CRD ===
test_build_mongodb_basic = lambda {
    _result = mongo.build_mongodb_community(mongo.MongoDBCommunitySpec {
        name = "my-mongo"
        namespace = "data"
        members = 3
        mongodbVersion = "7.0.12"
        storageSize = "10Gi"
    })
    assert _result.apiVersion == "mongodbcommunity.mongodb.com/v1"
    assert _result.kind == "MongoDBCommunity"
    assert _result.metadata.name == "my-mongo"
    assert _result.metadata.namespace == "data"
    assert _result.spec.members == 3
    assert _result.spec.version == "7.0.12"
    assert _result.spec.$type == "ReplicaSet"
}

# === Test: MongoDB with custom storage class ===
test_build_mongodb_with_storage_class = lambda {
    _result = mongo.build_mongodb_community(mongo.MongoDBCommunitySpec {
        name = "my-mongo"
        namespace = "data"
        members = 3
        mongodbVersion = "7.0.12"
        storageSize = "20Gi"
        storageClassName = "fast-ssd"
    })
    _pvc = _result.spec.statefulSet.spec.volumeClaimTemplates[0]
    assert _pvc.spec.storageClassName == "fast-ssd"
    assert _pvc.spec.resources.requests.storage == "20Gi"
}

# === Test: MongoDB with users ===
test_build_mongodb_with_user = lambda {
    _result = mongo.build_mongodb_community(mongo.MongoDBCommunitySpec {
        name = "my-mongo"
        namespace = "data"
        members = 3
        mongodbVersion = "7.0.12"
        storageSize = "10Gi"
        users = [mongo.MongoDBUserSpec {
            name = "app-user"
            database = "admin"
            passwordSecretName = "mongo-app-user-password"
            roles = [mongo.MongoDBRoleSpec {
                name = "readWrite"
                database = "myapp"
            }]
        }]
    })
    _user = _result.spec.users[0]
    assert _user.name == "app-user"
    assert _user.db == "admin"
    assert _user.passwordSecretRef.name == "mongo-app-user-password"
    assert _user.roles[0].name == "readWrite"
    assert _user.roles[0].db == "myapp"
}

# === Test: MongoDB with resources ===
test_build_mongodb_with_resources = lambda {
    _result = mongo.build_mongodb_community(mongo.MongoDBCommunitySpec {
        name = "my-mongo"
        namespace = "data"
        members = 3
        mongodbVersion = "7.0.12"
        storageSize = "10Gi"
        resources = {
            limits = {cpu = "1", memory = "2Gi"}
            requests = {cpu = "500m", memory = "1Gi"}
        }
    })
    assert _result.spec.statefulSet.spec.template.spec.containers[0].resources.limits.cpu == "1"
}

# === Test: Validation — members must be >= 1 ===
test_mongodb_rejects_zero_members = lambda {
    _err = runtime.catch(lambda {
        mongo.MongoDBCommunitySpec {
            name = "bad"
            namespace = "data"
            members = 0
            mongodbVersion = "7.0.12"
            storageSize = "10Gi"
        }
    })
    assert _err, "Expected validation error for members=0"
}

# === Test: Validation — mongodbVersion must not be empty ===
test_mongodb_rejects_empty_version = lambda {
    _err = runtime.catch(lambda {
        mongo.MongoDBCommunitySpec {
            name = "bad"
            namespace = "data"
            members = 3
            mongodbVersion = ""
            storageSize = "10Gi"
        }
    })
    assert _err, "Expected validation error for empty version"
}

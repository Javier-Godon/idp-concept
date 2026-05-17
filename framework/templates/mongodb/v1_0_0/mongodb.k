"""
MongoDB Community Template — MongoDB Community Kubernetes Operator pattern.
Generates: MongoDBCommunity CRD manifest.

CRD API: mongodbcommunity.mongodb.com/v1
Operator: MongoDB Community Kubernetes Operator (https://github.com/mongodb/mongodb-kubernetes-operator)
Migration: For MCK (mongodb-kubernetes) operator, see IDP_EVOLUTION_PLAN Phase 6.

Usage:
    import framework.templates.mongodb as mongo

    schema MyMongo(mongo.MongoDBCommunityModule):
        clusterName = "my-mongo"
        members = 3
        mongodbVersion = "7.0.12"
        storageSize = "10Gi"
        users = [mongo.MongoDBUserSpec {
            name = "app-user"
            database = "admin"
            passwordSecretName = "mongo-app-user-password"
            roles = [mongo.MongoDBRoleSpec { name = "readWrite", database = "myapp" }]
        }]
"""
import models.modules.accessory as accessory
import builders.leader as leader

schema MongoDBRoleSpec:
    """MongoDB user role specification."""
    name: str
    database: str

schema MongoDBUserSpec:
    """MongoDB user specification."""
    name: str
    database: str = "admin"
    passwordSecretName: str
    roles: [MongoDBRoleSpec]

    check:
        len(name) > 0, "user name must not be empty"
        len(passwordSecretName) > 0, "passwordSecretName must not be empty"
        len(roles) > 0, "at least one role is required"

schema MongoDBCommunitySpec:
    """Specification for a MongoDBCommunity resource."""
    name: str
    namespace: str
    members: int = 3
    mongodbVersion: str
    storageSize: str
    storageClassName?: str
    users?: [MongoDBUserSpec]
    resources?: any

    check:
        members >= 1, "members must be >= 1"
        len(mongodbVersion) > 0, "mongodbVersion must not be empty"
        len(storageSize) > 0, "storageSize must not be empty"

build_mongodb_community = lambda spec: MongoDBCommunitySpec -> any {
    _storage_class = {if spec.storageClassName: storageClassName = spec.storageClassName}
    _users = {
        if spec.users:
            users = [{
                name = u.name
                db = u.database
                passwordSecretRef = { name = u.passwordSecretName }
                roles = [{ name = r.name, db = r.database } for r in u.roles]
                scramCredentialsSecretName = "${u.name}-scram"
            } for u in spec.users]
    }
    _resources_container = {
        if spec.resources:
            template = {
                spec = {
                    containers = [{
                        name = "mongod"
                        resources = spec.resources
                    }]
                }
            }
    }
    _statefulset = {
        statefulSet = {
            spec = {
                volumeClaimTemplates = [{
                    metadata = { name = "data-volume" }
                    spec = {
                        resources = { requests = { storage = spec.storageSize } }
                    } | _storage_class
                }]
            } | _resources_container
        }
    }
    {
        apiVersion = "mongodbcommunity.mongodb.com/v1"
        kind = "MongoDBCommunity"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            members = spec.members
            $type = "ReplicaSet"
            version = spec.mongodbVersion
            security = {
                authentication = {
                    modes = ["SCRAM"]
                }
            }
        } | _statefulset | _users
    }
}

schema MongoDBCommunityModule(accessory.Accessory):
    """High-level template for MongoDB clusters via the Community Operator.

    Extends Accessory with kind="CRD" and generates MongoDBCommunity CRD manifest.
    """
    kind = "CRD"

    # User-configurable
    clusterName: str
    members?: int = 3
    mongodbVersion: str
    storageSize: str
    storageClassName?: str
    users?: [MongoDBUserSpec]
    resources?: any

    # Auto-computed
    leaders = [leader.build_accessory_leader(clusterName, namespace, "MongoDBCommunity", "mongodbcommunity.mongodb.com/v1")]

    _cluster_manifest = build_mongodb_community(MongoDBCommunitySpec {
        name = clusterName
        namespace = namespace
        members = members
        mongodbVersion = mongodbVersion
        storageSize = storageSize
        storageClassName = storageClassName
        users = users
        resources = resources
    })

    manifests = [_cluster_manifest]

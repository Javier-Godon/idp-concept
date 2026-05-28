"""
MongoDB Community Template — MongoDB Community Kubernetes Operator pattern.
Generates: MongoDBCommunity CRD manifest.

CRD API: mongodbcommunity.mongodb.com/v1
Operator: MongoDB Community Kubernetes Operator (https://github.com/mongodb/mongodb-kubernetes-operator)
Migration: For MCK (mongodb-kubernetes) operator, see IDP_EVOLUTION_PLAN Phase 6.

Usage:
    import framework.templates.mongodb.v1_0_0.mongodb as mongo

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
import templates.footprints.v1_0_0.footprint as fp
import templates.admin.v1_0_0.data_admin as admin

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
    footprint?: str = "production"
    members?: int
    mongodbVersion: str
    storageSize?: str
    storageClassName?: str
    users?: [MongoDBUserSpec]
    resources?: any

    check:
        footprint in ["local", "development", "staging", "production"], "footprint must be local, development, staging, or production"
        members >= 1 if members is not Undefined, "members must be >= 1"
        len(mongodbVersion) > 0, "mongodbVersion must not be empty"
        len(storageSize) > 0 if storageSize is not Undefined, "storageSize must not be empty"

build_mongodb_community = lambda spec: MongoDBCommunitySpec -> any {
    _members = spec.members if spec.members is not Undefined else fp.replicas(spec.footprint, 1, 1, 3, 3)
    _storage_size = spec.storageSize if spec.storageSize is not Undefined else fp.storage_size(spec.footprint, "1Gi", "2Gi", "8Gi", "10Gi")
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
                        resources = { requests = { storage = _storage_size } }
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
            members = _members
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
    footprint?: str = "production"
    clusterName: str
    members?: int
    mongodbVersion: str
    storageSize?: str
    storageClassName?: str
    users?: [MongoDBUserSpec]
    resources?: any
    mongoExpress?: admin.MongoExpressSpec

    # Auto-computed
    leaders = [leader.build_accessory_leader(clusterName, namespace, "MongoDBCommunity", "mongodbcommunity.mongodb.com/v1")]

    _cluster_manifest = build_mongodb_community(MongoDBCommunitySpec {
        name = clusterName
        namespace = namespace
        footprint = footprint
        members = members
        mongodbVersion = mongodbVersion
        storageSize = storageSize
        storageClassName = storageClassName
        users = users
        resources = resources
    })

    _mongo_express_manifests = admin.build_mongo_express_resources(mongoExpress) if mongoExpress else []

    manifests = [_cluster_manifest] + _mongo_express_manifests

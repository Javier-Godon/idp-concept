"""
Acceptance fixture: WebAppModule + MongoDBCommunityModule co-deployed in one stack.

Models a document-store web application IDP stack: a webapp Deployment wired to
a MongoDB Community CR in the same namespace. Both modules are rendered through a
single RenderStack via render_stack.

The webapp uses the pause image and sets MONGODB_URI to the MongoDB service name
and default port 27017.

Dry-run-only in acceptance_kind.sh. Real apply requires MongoDB Community Operator
and a working StorageClass (see docs/ACCEPTANCE_DEPENDENCIES.md).

Covers:
- Application + document-store IDP stack via render_stack
- WebApp Component + MongoDB Accessory in the same namespace
- MongoDBCommunity CR shape alongside Deployment resources in one manifest
- Cross-module env wiring: MONGODB_URI points at MongoDB service
"""

import ._helpers as h
import templates.webapp as webapp
import templates.mongodb as mongo

_namespace = "idp-acceptance-webapp-mongodb-stack"

_app = webapp.WebAppModule {
    name = "acceptance-webapp-mongo"
    namespace = _namespace
    configurations = {}
    asset = {
        image = "registry.k8s.io/pause"
        version = "3.10"
    }
    dependsOn = []
    port = 8080
    replicas = 1
    configData = {"application.yaml" = "server.port: 8080\nmongodb.uri: mongodb://acceptance-mongodb-stack-svc:27017/appdb\n"}
    env = [
        {name = "MONGODB_URI", value = "mongodb://acceptance-mongodb-stack-svc:27017/appdb"}
        {name = "MONGODB_DB", value = "appdb"}
    ]
}.instance

_mongodb = mongo.MongoDBCommunityModule {
    name = "acceptance-mongodb-stack"
    namespace = _namespace
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = []
    clusterName = "acceptance-mongodb-stack"
    members = 1
    mongodbVersion = "7.0.12"
    storageSize = "1Gi"
}.instance

h.render_stack([_namespace], [_app], [_mongodb])


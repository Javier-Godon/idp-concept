"""
Acceptance fixture: MongoDBCommunityModule through the IDP render path.
"""

import ._helpers as h
import templates.mongodb.v1_0_0.mongodb as mongo

_module = mongo.MongoDBCommunityModule {
    name = "acceptance-mongodb"
    namespace = "idp-acceptance-mongodb"
    configurations = {}
    asset = {version = "7.0.12"}
    dependsOn = []
    clusterName = "acceptance-mongodb"
    members = 1
    mongodbVersion = "7.0.12"
    storageSize = "1Gi"
}.instance

h.render_accessory("idp-acceptance-mongodb", _module)


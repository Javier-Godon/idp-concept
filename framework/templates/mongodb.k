"""Backward-compatible Mongodb template wrapper.

The implementation lives in `templates.mongodb.main`. Keep this root module thin so
existing imports such as `import templates.mongodb as mongodb` continue to work
without duplicating template implementation code.
"""

import templates.mongodb.main as mongodb_compat

MongoDBRoleSpec = mongodb_compat.MongoDBRoleSpec
MongoDBUserSpec = mongodb_compat.MongoDBUserSpec
MongoDBCommunitySpec = mongodb_compat.MongoDBCommunitySpec
build_mongodb_community = mongodb_compat.build_mongodb_community
MongoDBCommunityModule = mongodb_compat.MongoDBCommunityModule

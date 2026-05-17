"""
Versioned ecosystem path smoke test.

Ensures the new template folder convention exists and imports resolve, while
keeping backward-compatible root templates available.
"""

import templates.backstage.v1_0_0.backstage as backstage_v1_paths
import templates.ceph.v1_0_0.ceph as ceph_v1_paths
import templates.database.v1_0_0.database as database_v1_paths
import templates.kafka.v1_0_0.kafka as kafka_v1_paths
import templates.keycloak.v1_0_0.keycloak as keycloak_v1_paths
import templates.longhorn.v1_0_0.longhorn as longhorn_v1_paths
import templates.minio.v1_0_0.minio as minio_v1_paths
import templates.mongodb.v1_0_0.mongodb as mongodb_v1_paths
import templates.observability.v1_0_0.observability as observability_v1_paths
import templates.openbao.v1_0_0.openbao as openbao_v1_paths
import templates.opentelemetry.v1_0_0.opentelemetry as opentelemetry_v1_paths
import templates.opensearch.v2_17_0.opensearch as opensearch_v2_paths
import templates.opensearch.v2_17_0.opensearch_dashboards as opensearch_dashboards_v2_paths
import templates.opensearch.dataprepper.v2_10_2.dataprepper as dataprepper_v2_paths
import templates.postgresql.v1_0_0.postgresql as postgresql_v1_paths
import templates.questdb.v1_0_0.questdb as questdb_v1_paths
import templates.rabbitmq.v1_0_0.rabbitmq as rabbitmq_v1_paths
import templates.redis.v1_0_0.redis as redis_v1_paths
import templates.valkey.v1_0_0.valkey as valkey_v1_paths
import templates.vault.v1_0_0.vault as vault_v1_paths
import templates.webapp.v1_0_0.webapp as webapp_v1_paths

# Existing versioned elastic folders remain supported
import templates.elastic.v7_10_2.elasticsearch as elasticsearch_v7_paths
import templates.elastic.v9_4_1.elasticsearch as elasticsearch_v9_paths

# Root wrappers remain available for compatibility
import templates.elasticsearch as elasticsearch_wrapper_paths
import templates.kibana as kibana_wrapper_paths
import templates.logstash as logstash_wrapper_paths

test_versioned_ecosystem_imports_resolve = lambda {
    # If imports above fail, this test file does not compile.
    assert True
}


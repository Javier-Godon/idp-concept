# Search Stack Decision: Elasticsearch vs OpenSearch

> Practical engineering guidance, not legal advice. Ask counsel to review Elastic's current license terms before production adoption if the decision has commercial impact.

## Can we use Elasticsearch 9.4.1 internally?

For the scenario described — using Elasticsearch/Kibana/Logstash only as internal infrastructure and not selling a managed/search product that competes with Elastic — Elasticsearch 9.x is generally plausible to use under Elastic's source-available licensing model.

Important caveats:

- Elasticsearch 9.x and ECK are not Apache-2.0/OSI-open-source in the same sense as OpenSearch.
- Restrictions usually matter most if you offer Elasticsearch/Kibana as a hosted service, managed service, or competing product.
- Internal use for observability/search infrastructure is a different risk profile, but still requires license review.
- If the platform is intended to be redistributed to customers or run as a hosted commercial offering, prefer OpenSearch or get explicit legal approval.

## Recommendation

For this IDP, use this default policy:

| Scenario | Recommended stack | Why |
|---|---|---|
| General-purpose, redistributable, lowest license friction | OpenSearch | Apache-2.0 project, permissive usage, safer default for an IDP framework |
| Internal-only infrastructure, advanced Elastic-specific features needed | Elasticsearch 9.x via ECK | Strong Elastic ecosystem, recent features, official operator, acceptable if license review confirms usage |
| Legacy OSS-only Elastic compatibility | Elasticsearch/Kibana/Logstash OSS 7.10.2 | Last Apache-2.0 OSS Elastic artifact line, useful for compatibility but old |

## Functional/performance balance

### Elasticsearch 9.x advantages

- Very mature feature set.
- Strong official tooling around ECK, Kibana, Fleet/Agent, Elastic integrations, APM, ML, transforms, lifecycle/data-stream workflows, and security features.
- Usually the best choice when a team explicitly wants Elastic's current commercial/source-available ecosystem.

### OpenSearch advantages

- Lower license friction for platform frameworks and redistribution.
- OpenSearch, OpenSearch Dashboards, OpenSearch Operator, Data Prepper, ISM, Alerting, Security, Observability, and Performance Analyzer provide a strong open ecosystem.
- Better default for a public/internal developer platform because users can adopt it without Elastic-license ambiguity.

### Practical recommendation

Default to **OpenSearch** in shared framework examples and production platform blueprints.

Allow **Elasticsearch 9.4.1** as an explicitly selected versioned infrastructure template for internal deployments where the organization accepts Elastic's license terms.

## Template structure

Elastic templates are versioned explicitly:

```text
framework/templates/elastic/
  v7_10_2/
    elasticsearch.k   # Apache-2.0 OSS artifact line, Kubernetes-native StatefulSet
    kibana.k          # Apache-2.0 OSS artifact line, Kubernetes-native Deployment
    logstash.k        # Apache-2.0 OSS artifact line, Kubernetes-native Deployment
  v9_4_1/
    elasticsearch.k   # Elastic 9.4.1 via ECK Elasticsearch CRD
    kibana.k          # Elastic 9.4.1 via ECK Kibana CRD
    logstash.k        # Elastic 9.4.1 via ECK Logstash CRD
```

Use explicit versioned imports:

```kcl
import templates.elastic.v7_10_2.elasticsearch as es
import templates.elastic.v7_10_2.kibana as kibana
import templates.elastic.v7_10_2.logstash as logstash
```

Select a version namespace intentionally when comparing OSS 7.x native resources with Elastic 9.x ECK CRDs:

```kcl
import templates.elastic.v7_10_2.elasticsearch as es7
import templates.elastic.v9_4_1.elasticsearch as es9
```

## OpenSearch ecosystem coverage

Currently covered:

- `OpenSearchClusterModule` — OpenSearch Operator CRD (`opensearch.org/v1 OpenSearchCluster`).
- `OpenSearchDashboardsModule` — standalone OpenSearch Dashboards Deployment.
- `DataPrepperModule` — Data Prepper ingestion pipeline using Kubernetes-native resources.
- `OpenTelemetry` templates — useful for telemetry ingestion pipelines.
- Storage templates for Ceph/Longhorn-backed PVCs.

Potential additions still useful for a fuller OpenSearch platform:

| Missing piece | Why it matters | Suggested template |
|---|---|---|
| OpenSearch Operator installer | Cluster CRs require the operator to exist | `OpenSearchOperatorSpec` HelmRelease wrapper |
| OpenSearch Index State Management policies | Retention/rollover for logs and metrics | `OpenSearchISMPolicySpec` using ConfigMap/job or operator-supported CR if available |
| OpenSearch Alerting monitors | Production alerting | `OpenSearchMonitorSpec` |
| OpenSearch Security bootstrap | Roles/users mappings without hardcoded secrets | ExternalSecret + Job/Config pattern |
| OpenSearch snapshot repository setup | Backup/restore | `OpenSearchSnapshotRepositorySpec` |
| OpenSearch Ingestion/Data Prepper pipeline presets | Logs/traces/metrics defaults | Higher-level pipeline presets on top of `DataPrepperModule` |

## Usage examples

### OpenSearch default

```kcl
import templates.opensearch as os

schema SearchCluster(os.OpenSearchClusterModule):
    clusterName = "opensearch"
    version = "2.17.0"
    nodePools = [os.NodePoolSpec {
        component = "nodes"
        replicas = 3
        diskSize = "100Gi"
        roles = ["cluster_manager", "data", "ingest"]
    }]
    dashboards = os.DashboardsSpec {enable = True, replicas = 2, version = "2.17.0"}
```

### Elastic 9.4.1 internal-only option

```kcl
import templates.elastic.v9_4_1.elasticsearch as es

_es = es.build_elasticsearch_cluster(es.ElasticsearchSpec {
    name = "elasticsearch"
    namespace = "search"
    nodeSets = [es.ElasticsearchNodeSetSpec {
        name = "default"
        count = 3
        storageSize = "100Gi"
        storageClassName = "rook-ceph-block"
    }]
})
```


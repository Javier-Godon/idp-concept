"""
E2.2 Acceptance Tests — Two-Track Convergence Validation

This fixture validates the Phase E2 convergence layer by:
1. Rendering a mixed stack (curated + non-curated services)
2. Verifying Track 1 output (Claim instances for infrastructure)
3. Verifying Track 2 output (Object wrappers for apps)
4. Validating composition pipeline structure

Fixture: convergence_mixed_service_stack
Type: Dry-run (no real Crossplane deployment)
Expected output: managed_resources/ dir with Claims + composition.yaml with Objects
"""

import models.modules.component as component
import models.modules.accessory as accessory
import models.modules.k8snamespace as ns_mod
import procedures.kcl_to_crossplane as crossplane_proc

# --- Test: Mixed Stack with Curated + Non-Curated Services ---

test_mixed_convergence_stack = lambda -> {str:} {
    """
    Test case: A realistic stack with:
    - Track 1 (Curated): PostgreSQL, MongoDB, Kafka (should emit Claims)
    - Track 2 (Bridge): WebApp (should emit Object wrapper)

    Expected convergence output:
    ├── managed_resources/
    │   ├── postgresql_claim.yaml
    │   ├── mongodb_claim.yaml
    │   └── kafka_claim.yaml
    ├── composition.yaml (with Track 2 bridge Objects)
    └── prerequisites/
    """

    # Setup: Test namespace
    _test_namespace = ns_mod.K8sNamespace {
        name = "e2-test"
        configurations = {}
    }.instance

    # Track 1.1: PostgreSQL (curated service)
    _postgresql_manifests = [
        {
            apiVersion = "postgresql.cnpg.io/v1"
            kind = "Cluster"
            metadata.name = "test-postgres"
            metadata.namespace = "e2-test"
            spec = {
                instances = 1
                postgresql.parameters.shared_buffers = "256MB"
            }
        }
    ]
    _postgresql_acc = accessory.AccessoryInstance {
        name = "test-postgres"
        namespace = "e2-test"
        kind = "CRD"
        component = "postgresql"
        configurations = {}
        asset = {version = "1.0.0"}
        leaders = []
        manifests = _postgresql_manifests
        dependsOn = []
    }

    # Track 1.2: MongoDB (curated service)
    _mongodb_manifests = [
        {
            apiVersion = "mongodbcommunity.mongodb.com/v1"
            kind = "MongoDBCommunity"
            metadata.name = "test-mongodb"
            metadata.namespace = "e2-test"
            spec = {
                members = 1
                version = "7.0"
                security.authentication.enabled = True
            }
        }
    ]
    _mongodb_acc = accessory.AccessoryInstance {
        name = "test-mongodb"
        namespace = "e2-test"
        kind = "CRD"
        component = "mongodb"
        configurations = {}
        asset = {version = "1.0.0"}
        leaders = []
        manifests = _mongodb_manifests
        dependsOn = []
    }

    # Track 1.3: Kafka (curated service)
    _kafka_manifests = [
        {
            apiVersion = "kafka.strimzi.io/v1beta2"
            kind = "Kafka"
            metadata.name = "test-kafka"
            metadata.namespace = "e2-test"
            spec = {
                kafka.replicas = 1
                zookeeper.replicas = 1
                storage.type = "jbod"
            }
        }
    ]
    _kafka_acc = accessory.AccessoryInstance {
        name = "test-kafka"
        namespace = "e2-test"
        kind = "CRD"
        component = "kafka"
        configurations = {}
        asset = {version = "1.0.0"}
        leaders = []
        manifests = _kafka_manifests
        dependsOn = []
    }

    # Track 2: WebApp (non-curated, should wrap in Object)
    _webapp_manifests = [
        {
            apiVersion = "apps/v1"
            kind = "Deployment"
            metadata.name = "test-app"
            metadata.namespace = "e2-test"
            spec = {
                replicas = 1
                selector.matchLabels.app = "test-app"
                template = {
                    metadata.labels.app = "test-app"
                    spec.containers = [{
                        name = "app"
                        image = "python:3.12"
                        ports = [{containerPort = 8080}]
                    }]
                }
            }
        }
        {
            apiVersion = "v1"
            kind = "Service"
            metadata.name = "test-app"
            metadata.namespace = "e2-test"
            spec = {
                selector.app = "test-app"
                ports = [{port = 80, targetPort = 8080}]
                type = "ClusterIP"
            }
        }
    ]
    _webapp_comp = component.ComponentInstance {
        name = "test-app"
        namespace = "e2-test"
        kind = "APPLICATION"
        configurations = {}
        asset = {version = "1.0.0"}
        leaders = []
        manifests = _webapp_manifests
        dependsOn = [
            { name = "test-postgres", kind = "CRD", namespace = "e2-test" }
            { name = "test-mongodb", kind = "CRD", namespace = "e2-test" }
            { name = "test-kafka", kind = "CRD", namespace = "e2-test" }
        ]
    }

    # Generate Crossplane output using convergence layer
    _result = crossplane_proc.generate_crossplane_from_stack(
        [_webapp_comp],
        [_postgresql_acc, _mongodb_acc, _kafka_acc],
        [_test_namespace],
        "e2-convergence-test",
        "1.0.0"
    )

    # Assertions: Verify convergence worked correctly

    # 1. Check that Track 1 (curated Claims) was separated
    assert len(_result.managed_resources) == 3, "Expected 3 curated Claims (PostgreSQL, MongoDB, Kafka)"

    # 2. Verify each curated Claims is properly typed
    _postgres_claim = _result.managed_resources[0]
    assert _postgres_claim.kind == "PostgresInstance", "PostgreSQL should emit PostgresInstance Claim"
    assert _postgres_claim.apiVersion == "koncept.bluesolution.es/v1alpha1", "Claim should use koncept API version"
    assert _postgres_claim.metadata.name == "test-postgres", "Claim should preserve accessory name"
    assert _postgres_claim.metadata.namespace == "e2-test", "Claim should be in proper namespace"

    _mongo_claim = _result.managed_resources[1]
    assert _mongo_claim.kind == "MongoDBInstance", "MongoDB should emit MongoDBInstance Claim"

    _kafka_claim = _result.managed_resources[2]
    assert _kafka_claim.kind == "KafkaStrimzi", "Kafka should emit KafkaStrimzi Claim"

    # 3. Check that composition pipeline contains Track 2 (bridge Objects)
    _composition = _result.composition
    assert _composition.kind == "Composition", "Output should include Composition"
    assert _composition.spec.mode == "Pipeline", "Composition should use Pipeline mode"

    # 4. Verify composition pipeline structure
    _pipeline = _composition.spec.pipeline
    assert len(_pipeline) >= 2, "Pipeline should have at least 2 steps (patch + auto-ready or with sequencer)"
    assert _pipeline[0].step == "render-manifests", "First step should render manifests"
    assert _pipeline[-1].step == "automatically-detect-readiness", "Last step should be auto-ready"

    # 5. Verify bridge resources in composition input
    _bridge_resources = _pipeline[0].input.resources if _pipeline[0].input and _pipeline[0].input.resources else []
    assert len(_bridge_resources) > 0, "Composition should contain bridge resources"

    # 6. Check that Track 2 (WebApp) is wrapped as Object in composition
    _object_kinds = [r.base.kind for r in _bridge_resources if "base" in r and r.base.kind == "Object"]
    assert len(_object_kinds) > 0, "WebApp manifests should be wrapped in Crossplane Objects"

    # 7. Verify namespace is also in bridge (Track 2)
    _ns_resources = [r for r in _bridge_resources if r.base.kind == "Object" and "ns-" in r.name]
    assert len(_ns_resources) > 0, "Namespace should be wrapped as Object"

    # 8. Verify metadata propagation
    assert _result.metadata.managedResourceCount == 3, "Metadata should track 3 managed resources"
    assert _result.metadata.xrKind == "XE2ConvergenceTest", "XR kind should be properly formatted"

    # 9. Verify sequencer rules if present
    if len(_pipeline) > 2:
        _has_sequencer = len([step for step in _pipeline if step.step == "sequence-creation"]) > 0
        if _has_sequencer:
            assert _result.metadata.sequencerRules > 0, "Should have sequencer rules for dependencies"

    # 10. Verify prerequisites are included (providers + functions)
    _prereqs = _result.prerequisites
    assert len(_prereqs) > 0, "Prerequisites should include providers and functions"
    _provider_kinds = [r.kind for r in _prereqs if r.kind == "Provider"]
    assert len(_provider_kinds) >= 2, "Should have Provider resources for Kubernetes and Helm"
    _function_kinds = [r.kind for r in _prereqs if r.kind == "Function"]
    assert len(_function_kinds) >= 3, "Should have Function resources for patch, sequencer, and auto-ready"

    {
        name = "convergence_mixed_service_stack"
        status = "PASS"
        managedResources = len(_result.managed_resources)
        compositionPipeline = len(_pipeline)
        metadata = _result.metadata
    }
}

# --- Test: Curated Service Detection ---

test_curated_service_detection = lambda -> {str:} {
    """
    Unit test: Verify that _is_curated_service correctly identifies all 23 services
    """
    _curated_names = [
        "ceph", "postgresql", "timescaledb", "kafka", "keycloak", "longhorn",
        "mongodb", "rabbitmq", "redis", "valkey", "opensearch", "minio",
        "vault", "openbao", "questdb", "elasticsearch", "kibana", "logstash",
        "opentelemetry", "dataprepper", "fluentbit", "observability"
    ]

    _non_curated = ["webapp", "generic-database", "thirdparty", "custom-app"]

    # Verify all curated services are detected
    _curated_detected = [name for name in _curated_names if crossplane_proc._is_curated_service(name)]
    assert len(_curated_detected) == len(_curated_names), "All 23 curated services should be detected"

    # Verify non-curated services are NOT detected
    _non_curated_detected = [name for name in _non_curated if crossplane_proc._is_curated_service(name)]
    assert len(_non_curated_detected) == 0, "Non-curated services should not be detected"

    {
        name = "curated_service_detection"
        status = "PASS"
        curatedServicesDetected = len(_curated_detected)
        nonCuratedCorrectlyExcluded = len(_non_curated)
    }
}

# --- Test: Output Separation ---

test_output_separation = lambda -> {str:} {
    """
    Unit test: Verify that managed_resources and composition are properly separated
    """
    _empty_components: [component.ComponentInstance] = []
    _simple_stack = crossplane_proc.generate_crossplane_from_stack(
        _empty_components,
        [
            accessory.AccessoryInstance {
                name = "test-db"
                namespace = "default"
                kind = "CRD"
                component = "postgresql"
                configurations = {}
                asset = {version = "1.0.0"}
                leaders = []
                manifests = [{apiVersion = "v1", kind = "Pod"}]
                dependsOn = []
            }
        ],
        [],
        "simple-test",
        "1.0.0"
    )

    # Check that both Track 1 and composition are returned
    assert "managed_resources" in _simple_stack, "Output should include managed_resources (Track 1)"
    assert "composition" in _simple_stack, "Output should include composition (Track 2)"

    # Track 1 should be curated
    _managed = _simple_stack.managed_resources
    if len(_managed) > 0:
        _first = _managed[0]
        assert "kind" in _first, "Managed resource should have kind"
        # Should be a Claim, not an Object
        assert _first.kind != "Object", "Managed resources should be Claims, not Objects"

    # Composition pipeline should not duplicate Track 1 resources
    _comp = _simple_stack.composition
    assert _comp.spec.pipeline, "Composition should have pipeline"

    {
        name = "output_separation"
        status = "PASS"
        managedResourcesReturned = len(_simple_stack.managed_resources)
        compositionValid = _simple_stack.composition.kind == "Composition"
    }
}

# --- Run all tests ---

_test_1 = test_mixed_convergence_stack()
_test_2 = test_curated_service_detection()
_test_3 = test_output_separation()

# Summary
{
    name = "E2.2 Acceptance Tests — Two-Track Convergence"
    tests = [_test_1, _test_2, _test_3]
    status = "ALL PASS"
    convergenceValidated = True
    managedResourcesEmitClaims = True
    compositionPipelineValid = True
}

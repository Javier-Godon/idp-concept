import builders.service_account as sa

# === Test: Basic ServiceAccount ===
test_build_service_account_basic = lambda {
    _spec = sa.ServiceAccountSpec {
        name = "my-app"
        namespace = "apps"
    }
    _result = sa.build_service_account(_spec)
    assert _result.metadata.name == "my-app"
    assert _result.metadata.namespace == "apps"
    assert _result.kind == "ServiceAccount"
    assert _result.apiVersion == "v1"
}

# === Test: ServiceAccount with imagePullSecret ===
test_build_service_account_with_pull_secret = lambda {
    _spec = sa.ServiceAccountSpec {
        name = "my-app"
        namespace = "apps"
        imagePullSecretName = "registry-creds"
    }
    _result = sa.build_service_account(_spec)
    assert _result.imagePullSecrets[0].name == "registry-creds"
}

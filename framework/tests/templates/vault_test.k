"""
HashiCorp Vault Secrets Operator (VSO) Template Tests.

Tests the build functions for Vault Secrets Operator CRDs:
- VaultConnection (secrets.hashicorp.com/v1beta1)
- VaultAuth (secrets.hashicorp.com/v1beta1)
- VaultStaticSecret (secrets.hashicorp.com/v1beta1)
"""
import templates.vault as vault
import runtime

# === Test: build_vault_connection basic ===
test_build_vault_connection_basic = lambda {
    _result = vault.build_vault_connection(vault.VaultConnectionSpec {
        name = "vault-conn"
        namespace = "secrets"
        address = "https://vault.example.com:8200"
    })
    assert _result.apiVersion == "secrets.hashicorp.com/v1beta1"
    assert _result.kind == "VaultConnection"
    assert _result.metadata.name == "vault-conn"
    assert _result.metadata.namespace == "secrets"
    assert _result.spec.address == "https://vault.example.com:8200"
}

# === Test: build_vault_connection with TLS ===
test_build_vault_connection_tls = lambda {
    _result = vault.build_vault_connection(vault.VaultConnectionSpec {
        name = "vault-conn"
        namespace = "secrets"
        address = "https://vault.example.com:8200"
        caCertSecretRef = "vault-ca-cert"
        skipTLSVerify = False
    })
    assert _result.spec.caCertSecretRef == "vault-ca-cert"
    assert _result.spec.skipTLSVerify == False
}

# === Test: build_vault_auth Kubernetes method ===
test_build_vault_auth_kubernetes = lambda {
    _result = vault.build_vault_auth(vault.VaultAuthSpec {
        name = "vault-auth"
        namespace = "secrets"
        vaultConnectionRef = "vault-conn"
        method = "kubernetes"
        mount = "kubernetes"
        kubernetesRole = "my-role"
        kubernetesServiceAccount = "my-sa"
    })
    assert _result.apiVersion == "secrets.hashicorp.com/v1beta1"
    assert _result.kind == "VaultAuth"
    assert _result.spec.vaultConnectionRef == "vault-conn"
    assert _result.spec.method == "kubernetes"
    assert _result.spec.mount == "kubernetes"
    assert _result.spec.kubernetes.role == "my-role"
    assert _result.spec.kubernetes.serviceAccount == "my-sa"
}

# === Test: build_vault_static_secret KV v2 ===
test_build_vault_static_secret = lambda {
    _result = vault.build_vault_static_secret(vault.VaultStaticSecretSpec {
        name = "app-secrets"
        namespace = "apps"
        vaultAuthRef = "vault-auth"
        mount = "secret"
        path = "data/myapp/config"
        $type = "kv-v2"
        refreshAfter = "60s"
        destinationSecretName = "app-secrets-k8s"
    })
    assert _result.apiVersion == "secrets.hashicorp.com/v1beta1"
    assert _result.kind == "VaultStaticSecret"
    assert _result.metadata.name == "app-secrets"
    assert _result.spec.vaultAuthRef == "vault-auth"
    assert _result.spec.mount == "secret"
    assert _result.spec.path == "data/myapp/config"
    assert _result.spec.$type == "kv-v2"
    assert _result.spec.refreshAfter == "60s"
    assert _result.spec.destination.name == "app-secrets-k8s"
    assert _result.spec.destination.create == True
}

# === Test: vault_static_secret with custom destination ===
test_build_vault_static_secret_custom_dest = lambda {
    _result = vault.build_vault_static_secret(vault.VaultStaticSecretSpec {
        name = "db-creds"
        namespace = "data"
        vaultAuthRef = "vault-auth"
        mount = "database"
        path = "creds/postgres"
        $type = "kv-v1"
        destinationSecretName = "db-credentials"
        destinationCreate = False
    })
    assert _result.spec.destination.name == "db-credentials"
    assert _result.spec.destination.create == False
}

# === Test: Validation — method must be valid ===
test_vault_auth_rejects_invalid_method = lambda {
    _err = runtime.catch(lambda {
        vault.VaultAuthSpec {
            name = "bad"
            namespace = "ns"
            vaultConnectionRef = "conn"
            method = "invalid"
            mount = "auth"
        }
    })
    assert _err, "Expected validation error for invalid auth method"
}

# === Test: Validation — type must be valid ===
test_vault_static_secret_rejects_invalid_type = lambda {
    _err = runtime.catch(lambda {
        vault.VaultStaticSecretSpec {
            name = "bad"
            namespace = "ns"
            vaultAuthRef = "auth"
            mount = "secret"
            path = "data/test"
            $type = "invalid"
            destinationSecretName = "test"
        }
    })
    assert _err, "Expected validation error for invalid type"
}

"""
HashiCorp Vault Secrets Operator (VSO) Template.
Generates: VaultConnection, VaultAuth, VaultStaticSecret CRD manifests.

CRD API: secrets.hashicorp.com/v1beta1
Operator: Vault Secrets Operator (https://github.com/hashicorp/vault-secrets-operator)
License: BUSL-1.1 — NOT fully open-source. For Apache-2.0 alternative, use ExternalSecrets operator.

Usage:
    import framework.templates.vault as vault

    _conn = vault.build_vault_connection(vault.VaultConnectionSpec {
        name = "vault-conn"
        namespace = "secrets"
        address = "https://vault.example.com:8200"
    })
    _auth = vault.build_vault_auth(vault.VaultAuthSpec {
        name = "vault-auth"
        namespace = "secrets"
        vaultConnectionRef = "vault-conn"
        method = "kubernetes"
        mount = "kubernetes"
        kubernetesRole = "my-role"
        kubernetesServiceAccount = "my-sa"
    })
    _secret = vault.build_vault_static_secret(vault.VaultStaticSecretSpec {
        name = "app-secrets"
        namespace = "apps"
        vaultAuthRef = "vault-auth"
        mount = "secret"
        path = "data/myapp/config"
        type = "kv-v2"
        destinationSecretName = "app-secrets-k8s"
    })
"""

# --- VaultConnection ---

schema VaultConnectionSpec:
    """Specification for a VaultConnection resource."""
    name: str
    namespace: str
    address: str
    caCertSecretRef?: str
    skipTLSVerify?: bool
    headers?: {str:str}

    check:
        len(address) > 0, "address must not be empty"

build_vault_connection = lambda spec: VaultConnectionSpec -> any {
    _tls = {
        if spec.caCertSecretRef:
            caCertSecretRef = spec.caCertSecretRef
        if spec.skipTLSVerify is not Undefined:
            skipTLSVerify = spec.skipTLSVerify
    }
    _headers = {if spec.headers: headers = spec.headers}
    {
        apiVersion = "secrets.hashicorp.com/v1beta1"
        kind = "VaultConnection"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            address = spec.address
        } | _tls | _headers
    }
}

# --- VaultAuth ---

schema VaultAuthSpec:
    """Specification for a VaultAuth resource."""
    name: str
    namespace: str
    vaultConnectionRef: str
    method: str
    mount: str
    kubernetesRole?: str
    kubernetesServiceAccount?: str

    check:
        method in ["kubernetes", "jwt", "appRole"], "method must be one of: kubernetes, jwt, appRole"

build_vault_auth = lambda spec: VaultAuthSpec -> any {
    _kubernetes = {
        if spec.method == "kubernetes" and spec.kubernetesRole:
            kubernetes = {
                role = spec.kubernetesRole
                if spec.kubernetesServiceAccount:
                    serviceAccount = spec.kubernetesServiceAccount
            }
    }
    {
        apiVersion = "secrets.hashicorp.com/v1beta1"
        kind = "VaultAuth"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            vaultConnectionRef = spec.vaultConnectionRef
            method = spec.method
            mount = spec.mount
        } | _kubernetes
    }
}

# --- VaultStaticSecret ---

schema VaultStaticSecretSpec:
    """Specification for a VaultStaticSecret resource."""
    name: str
    namespace: str
    vaultAuthRef: str
    mount: str
    path: str
    $type: str = "kv-v2"
    refreshAfter?: str = "60s"
    destinationSecretName: str
    destinationCreate?: bool = True

    check:
        $type in ["kv-v1", "kv-v2"], "type must be one of: kv-v1, kv-v2"

build_vault_static_secret = lambda spec: VaultStaticSecretSpec -> any {
    {
        apiVersion = "secrets.hashicorp.com/v1beta1"
        kind = "VaultStaticSecret"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            vaultAuthRef = spec.vaultAuthRef
            mount = spec.mount
            path = spec.path
            $type = spec.$type
            if spec.refreshAfter:
                refreshAfter = spec.refreshAfter
            destination = {
                name = spec.destinationSecretName
                create = spec.destinationCreate
            }
        }
    }
}

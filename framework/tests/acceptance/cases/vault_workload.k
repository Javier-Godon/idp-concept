"""
Acceptance fixture: Vault Secrets Operator CRs through the IDP render path.
"""
import ._helpers as h
import templates.vault as vault
_namespace = "idp-acceptance-vault"
_resources = [
    vault.build_vault_connection(vault.VaultConnectionSpec {
        name = "acceptance-vault-connection"
        namespace = _namespace
        address = "https://vault.example.internal:8200"
        skipTLSVerify = True
    })
    vault.build_vault_auth(vault.VaultAuthSpec {
        name = "acceptance-vault-auth"
        namespace = _namespace
        vaultConnectionRef = "acceptance-vault-connection"
        method = "kubernetes"
        mount = "kubernetes"
        kubernetesRole = "acceptance"
        kubernetesServiceAccount = "default"
    })
    vault.build_vault_static_secret(vault.VaultStaticSecretSpec {
        name = "acceptance-vault-static-secret"
        namespace = _namespace
        vaultAuthRef = "acceptance-vault-auth"
        mount = "secret"
        path = "data/acceptance/config"
        destinationSecretName = "acceptance-secret"
    })
]
_module = h.wrap_accessory("acceptance-vault", _namespace, "secrets.hashicorp.com/v1beta1", "VaultStaticSecret", _resources, "1.0.0")
h.render_accessory(_namespace, _module)

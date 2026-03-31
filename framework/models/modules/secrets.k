"""
Secret management schemas — formalized references to K8s secrets and external secret stores.
Supports both native K8s Secret references and ExternalSecrets operator resources.
"""

schema SecretReference:
    """Reference to a Kubernetes Secret key."""
    secretName: str
    key: str
    optional: bool = False

schema ExternalSecret:
    """Reference to an external secret store (Vault, AWS Secrets Manager, Azure Key Vault)."""
    store: str
    key: str
    property?: str
    refreshInterval: str = "1h"

    check:
        store in ["vault", "aws-secrets-manager", "azure-key-vault", "gcp-secret-manager"], "store must be one of: vault, aws-secrets-manager, azure-key-vault, gcp-secret-manager"

# --- ExternalSecrets operator manifest generation ---

schema RemoteRef:
    """Remote reference to a secret in the external store."""
    key: str
    property?: str
    version?: str

schema ExternalSecretData:
    """Single data entry mapping a remote secret to a local key."""
    secretKey: str
    remoteRef: RemoteRef

schema ExternalSecretTarget:
    """Target Kubernetes Secret to create/update."""
    name: str
    creationPolicy?: str = "Owner"

schema ExternalSecretSpec:
    """Spec for generating an ExternalSecret K8s manifest."""
    name: str
    namespace: str
    secretStoreName: str
    target: ExternalSecretTarget
    data: [ExternalSecretData]
    refreshInterval: str = "1h"

build_external_secret = lambda spec: ExternalSecretSpec -> any {
    {
        apiVersion = "external-secrets.io/v1beta1"
        kind = "ExternalSecret"
        metadata = {
            name = spec.name
            namespace = spec.namespace
        }
        spec = {
            refreshInterval = spec.refreshInterval
            secretStoreRef = {
                name = spec.secretStoreName
                kind = "SecretStore"
            }
            target = {
                name = spec.target.name
                if spec.target.creationPolicy is not Undefined:
                    creationPolicy = spec.target.creationPolicy
            }
            data = [
                {
                    secretKey = d.secretKey
                    remoteRef = {
                        key = d.remoteRef.key
                        if d.remoteRef.property is not Undefined:
                            property = d.remoteRef.property
                        if d.remoteRef.version is not Undefined:
                            version = d.remoteRef.version
                    }
                }
                for d in spec.data
            ]
        }
    }
}

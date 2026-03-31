import models.modules.secrets as sec
import runtime

# --- Test: SecretReference basic ---
test_secret_reference = lambda {
    _ref = sec.SecretReference {
        secretName = "db-creds"
        key = "password"
    }
    assert _ref.secretName == "db-creds"
    assert _ref.key == "password"
    assert _ref.optional == False
}

# --- Test: SecretReference optional ---
test_secret_reference_optional = lambda {
    _ref = sec.SecretReference {
        secretName = "optional-secret"
        key = "token"
        optional = True
    }
    assert _ref.optional == True
}

# --- Test: ExternalSecret basic ---
test_external_secret = lambda {
    _ext = sec.ExternalSecret {
        store = "vault"
        key = "secret/data/myapp"
        property = "password"
    }
    assert _ext.store == "vault"
    assert _ext.key == "secret/data/myapp"
    assert _ext.property == "password"
    assert _ext.refreshInterval == "1h"
}

# --- Test: ExternalSecret custom refresh ---
test_external_secret_custom_refresh = lambda {
    _ext = sec.ExternalSecret {
        store = "aws-secrets-manager"
        key = "prod/db-password"
        refreshInterval = "30m"
    }
    assert _ext.refreshInterval == "30m"
    assert _ext.property is Undefined
}

# --- Test: ExternalSecret invalid store ---
test_external_secret_invalid_store = lambda {
    _err = runtime.catch(lambda {
        sec.ExternalSecret {
            store = "invalid-store"
            key = "test"
        }
    })
    assert _err != Undefined, "expected check block to reject invalid store"
}

# --- Test: build_external_secret_manifest ---
test_build_external_secret_manifest = lambda {
    _result = sec.build_external_secret(sec.ExternalSecretSpec {
        name = "db-password"
        namespace = "apps"
        secretStoreName = "vault-backend"
        target = sec.ExternalSecretTarget {
            name = "db-creds"
        }
        data = [
            sec.ExternalSecretData {
                secretKey = "password"
                remoteRef = sec.RemoteRef {
                    key = "secret/data/myapp"
                    property = "password"
                }
            }
        ]
        refreshInterval = "1h"
    })
    assert _result.apiVersion == "external-secrets.io/v1beta1"
    assert _result.kind == "ExternalSecret"
    assert _result.metadata.name == "db-password"
    assert _result.spec.secretStoreRef.name == "vault-backend"
    assert _result.spec.target.name == "db-creds"
    assert len(_result.spec.data) == 1
}

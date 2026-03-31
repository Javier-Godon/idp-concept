import runtime
import models.modules.common as common

# === Test: EnvVar with value ===
test_envvar_with_value = lambda {
    _env = common.EnvVar {
        name = "MY_VAR"
        value = "hello"
    }
    assert _env.name == "MY_VAR"
    assert _env.value == "hello"
}

# === Test: EnvVar with secretKeyRef ===
test_envvar_with_secret_ref = lambda {
    _env = common.EnvVar {
        name = "DB_PASSWORD"
        valueFrom = common.EnvVarSource {
            secretKeyRef = common.KeySelector {
                name = "db-credentials"
                key = "password"
            }
        }
    }
    assert _env.name == "DB_PASSWORD"
    assert _env.valueFrom.secretKeyRef.name == "db-credentials"
    assert _env.valueFrom.secretKeyRef.key == "password"
}

# === Test: EnvVar with configMapKeyRef ===
test_envvar_with_configmap_ref = lambda {
    _env = common.EnvVar {
        name = "APP_CONFIG"
        valueFrom = common.EnvVarSource {
            configMapKeyRef = common.KeySelector {
                name = "app-config"
                key = "setting"
            }
        }
    }
    assert _env.valueFrom.configMapKeyRef.name == "app-config"
}

# === Test: EnvVar must have value or valueFrom ===
test_envvar_missing_both = lambda {
    _msg = runtime.catch(lambda {
        common.EnvVar {
            name = "EMPTY"
        }
    })
    assert _msg == "env var must have either value or valueFrom"
}

# === Test: EnvVar cannot have both value and valueFrom ===
test_envvar_both_value_and_valuefrom = lambda {
    _msg = runtime.catch(lambda {
        common.EnvVar {
            name = "CONFLICT"
            value = "direct"
            valueFrom = common.EnvVarSource {
                secretKeyRef = common.KeySelector {
                    name = "secret"
                    key = "key"
                }
            }
        }
    })
    assert _msg == "env var cannot have both value and valueFrom"
}

# === Test: EnvVarSource must have exactly one ref ===
test_envvarsource_both_refs = lambda {
    _msg = runtime.catch(lambda {
        common.EnvVarSource {
            secretKeyRef = common.KeySelector { name = "s", key = "k" }
            configMapKeyRef = common.KeySelector { name = "c", key = "k" }
        }
    })
    assert _msg == "envVarSource cannot have both secretKeyRef and configMapKeyRef"
}

# === Test: EnvVarSource must have at least one ref ===
test_envvarsource_no_ref = lambda {
    _msg = runtime.catch(lambda {
        common.EnvVarSource {}
    })
    assert _msg == "envVarSource must have either secretKeyRef or configMapKeyRef"
}

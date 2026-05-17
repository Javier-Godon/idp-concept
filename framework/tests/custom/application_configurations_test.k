"""
Application configuration helper tests.

Validates standard runtime config files, environment variables, overrides, and valueFrom support.
"""
import custom.application_configurations as appcfg
import runtime

# === Test: Python defaults produce YAML config and env vars ===
test_application_config_python_defaults = lambda {
    _spec = appcfg.ApplicationConfigSpec {
        runtime = "python"
        applicationName = "orders-api"
        environment = "dev"
        port = 8000
        apiBaseUrl = "https://api.dev.example.com"
    }
    _data = appcfg.build_config_data(_spec)
    _env = appcfg.build_env_map(_spec)

    assert _data["config.yaml"] != Undefined
    assert "name: orders-api" in _data["config.yaml"]
    assert "port: 8000" in _data["config.yaml"]
    assert _env["APP_NAME"] == "orders-api"
    assert _env["PORT"] == "8000"
    assert _env["PYTHONUNBUFFERED"] == "1"
}

# === Test: Rust uses TOML config ===
test_application_config_rust_toml = lambda {
    _data = appcfg.build_config_data(appcfg.ApplicationConfigSpec {
        runtime = "rust"
        applicationName = "ingestor"
        environment = "production"
        port = 9000
        properties = {
            "workers" = "4"
        }
    })

    assert _data["config.toml"] != Undefined
    assert "[app]" in _data["config.toml"]
    assert "name = \"ingestor\"" in _data["config.toml"]
    assert "workers = \"4\"" in _data["config.toml"]
}

# === Test: Frontend runtimes use JSON and framework-specific public env vars ===
test_application_config_next_json_and_env = lambda {
    _spec = appcfg.ApplicationConfigSpec {
        runtime = "next"
        applicationName = "portal"
        environment = "stg"
        apiBaseUrl = "https://api.stg.example.com"
        publicBaseUrl = "https://portal.stg.example.com"
    }
    _data = appcfg.build_config_data(_spec)
    _env = appcfg.build_env_map(_spec)

    assert _data["runtime-config.json"] != Undefined
    assert "\"name\": \"portal\"" in _data["runtime-config.json"]
    assert _env["NEXT_PUBLIC_API_BASE_URL"] == "https://api.stg.example.com"
    assert _env["NEXT_PUBLIC_BASE_URL"] == "https://portal.stg.example.com"
}

# === Test: extra config files override defaults ===
test_application_config_file_overrides = lambda {
    _data = appcfg.build_config_data(appcfg.ApplicationConfigSpec {
        runtime = "go"
        applicationName = "worker"
        configFiles = {
            "config.yaml" = "from: configFiles\n"
            "extra.yaml" = "enabled: true\n"
        }
        extraConfigFiles = {
            "config.yaml" = "from: extraConfigFiles\n"
        }
    })

    assert _data["config.yaml"] == "from: extraConfigFiles\n"
    assert _data["extra.yaml"] == "enabled: true\n"
}

# === Test: env overrides and valueFrom env vars ===
test_application_config_env_vars = lambda {
    _env = appcfg.build_env_vars(appcfg.ApplicationConfigSpec {
        runtime = "kotlin"
        applicationName = "billing"
        environment = "prod"
        port = 8080
        env = {
            LOG_LEVEL = "WARN"
        }
        extraEnv = {
            LOG_LEVEL = "ERROR"
        }
        secretEnvVars = [appcfg.EnvVar {
            name = "DB_PASSWORD"
            secretKeyRef = appcfg.SecretKeySelector {
                name = "billing-db"
                key = "password"
            }
        }]
    })

    _log = [item for item in _env if item.name == "LOG_LEVEL"][0]
    _secret = [item for item in _env if item.name == "DB_PASSWORD"][0]
    _server_port = [item for item in _env if item.name == "SERVER_PORT"][0]

    assert _log.value == "ERROR"
    assert _server_port.value == "8080"
    assert _secret.valueFrom.secretKeyRef.name == "billing-db"
    assert _secret.valueFrom.secretKeyRef.key == "password"
}

# === Test: bundle shape is ready for WebAppModule ===
test_application_config_bundle = lambda {
    _bundle = appcfg.build_config_bundle(appcfg.ApplicationConfigSpec {
        runtime = "angular"
        applicationName = "admin-ui"
        apiBaseUrl = "https://api.example.com"
    })

    assert _bundle.configData["assets/config.json"] != Undefined
    assert len(_bundle.env) > 0
}

# === Test: validation rejects invalid port ===
test_application_config_rejects_invalid_port = lambda {
    _err = runtime.catch(lambda {
        appcfg.ApplicationConfigSpec {
            runtime = "go"
            applicationName = "api"
            port = 70000
        }
    })
    assert _err != Undefined, "Expected invalid port validation error"
}


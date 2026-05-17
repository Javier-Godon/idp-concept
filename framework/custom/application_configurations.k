"""
Application configuration helper for common runtimes and frontend frameworks.

The helper builds two things that WebAppModule already accepts:
- ConfigMap data (`configData`) with standard runtime files plus free-form files.
- Kubernetes-style environment variable lists (`env`).

It intentionally keeps defaults small and portable. Add project-specific settings with
`properties`, `extraProperties`, `configFiles`, `extraConfigFiles`, `env`, `extraEnv`,
`envVars`, and `secretEnvVars`.
"""

schema SecretKeySelector:
    name: str
    key: str

schema EnvVar:
    name: str
    value?: str
    secretKeyRef?: SecretKeySelector
    configMapKeyRef?: SecretKeySelector

    check:
        value != Undefined or secretKeyRef != Undefined or configMapKeyRef != Undefined, "env var must define value, secretKeyRef, or configMapKeyRef"
        not (value != Undefined and (secretKeyRef != Undefined or configMapKeyRef != Undefined)), "env var value cannot be combined with valueFrom selectors"
        not (secretKeyRef != Undefined and configMapKeyRef != Undefined), "env var cannot use both secretKeyRef and configMapKeyRef"

schema ApplicationConfigSpec:
    """General application configuration spec.

    Runtime values supported by `build_config_data`:
    python, go, rust, kotlin, vue, nuxt, angular, react, next.
    """
    runtime: "python" | "go" | "rust" | "kotlin" | "vue" | "nuxt" | "angular" | "react" | "next"
    applicationName: str
    environment?: str = "default"
    port?: int
    logLevel?: str = "INFO"
    apiBaseUrl?: str
    publicBaseUrl?: str

    # Values included in generated config files under runtime-specific sections.
    properties?: {str:str}
    # Applied after `properties`, so it can override generated/custom values.
    extraProperties?: {str:str}

    # Additional ConfigMap data. `extraConfigFiles` wins over `configFiles` and defaults.
    configFiles?: {str:str}
    extraConfigFiles?: {str:str}

    # Direct environment variable maps. `extraEnv` wins over generated env and `env`.
    env?: {str:str}
    extraEnv?: {str:str}

    # Fully custom env vars for valueFrom or explicit entries.
    envVars?: [EnvVar]
    secretEnvVars?: [EnvVar]

    check:
        len(applicationName) > 0, "applicationName must not be empty"
        1 <= port <= 65535 if port != Undefined, "port must be between 1 and 65535"

_default_config_file_name = lambda runtime: str -> str {
    _names = {
        python = "config.yaml"
        go = "config.yaml"
        rust = "config.toml"
        kotlin = "application.yaml"
        vue = "runtime-config.json"
        nuxt = "runtime-config.json"
        angular = "assets/config.json"
        react = "runtime-config.json"
        next = "runtime-config.json"
    }
    _names[runtime]
}

_build_yaml_like_config = lambda spec: ApplicationConfigSpec -> str {
    _port_line = "\n  port: ${spec.port}" if spec.port != Undefined else ""
    _api_line = "\n  apiBaseUrl: ${spec.apiBaseUrl}" if spec.apiBaseUrl else ""
    _public_line = "\n  publicBaseUrl: ${spec.publicBaseUrl}" if spec.publicBaseUrl else ""
    _property_lines = "\n".join(["  ${key}: ${value}" for key, value in ((spec.properties or {}) | (spec.extraProperties or {}))])
    _properties_block = "\nproperties:\n${_property_lines}" if _property_lines else ""
    "app:\n  name: ${spec.applicationName}\n  environment: ${spec.environment}${_port_line}\nlogging:\n  level: ${spec.logLevel}${_api_line}${_public_line}${_properties_block}\n"
}

_build_toml_config = lambda spec: ApplicationConfigSpec -> str {
    _port_line = "\nport = ${spec.port}" if spec.port != Undefined else ""
    _api_line = "\napi_base_url = \"${spec.apiBaseUrl}\"" if spec.apiBaseUrl else ""
    _public_line = "\npublic_base_url = \"${spec.publicBaseUrl}\"" if spec.publicBaseUrl else ""
    _property_lines = "\n".join(["${key} = \"${value}\"" for key, value in ((spec.properties or {}) | (spec.extraProperties or {}))])
    _properties_block = "\n\n[properties]\n${_property_lines}" if _property_lines else ""
    "[app]\nname = \"${spec.applicationName}\"\nenvironment = \"${spec.environment}\"${_port_line}\n\n[logging]\nlevel = \"${spec.logLevel}\"${_api_line}${_public_line}${_properties_block}\n"
}

_build_json_config = lambda spec: ApplicationConfigSpec -> str {
    _port_line = ",\n    \"port\": ${spec.port}" if spec.port != Undefined else ""
    _api_line = ",\n    \"apiBaseUrl\": \"${spec.apiBaseUrl}\"" if spec.apiBaseUrl else ""
    _public_line = ",\n    \"publicBaseUrl\": \"${spec.publicBaseUrl}\"" if spec.publicBaseUrl else ""
    _property_lines = ",\n".join(["    \"${key}\": \"${value}\"" for key, value in ((spec.properties or {}) | (spec.extraProperties or {}))])
    _properties_block = ",\n  \"properties\": {\n${_property_lines}\n  }" if _property_lines else ""
    "{\n  \"app\": {\n    \"name\": \"${spec.applicationName}\",\n    \"environment\": \"${spec.environment}\"${_port_line}${_api_line}${_public_line}\n  },\n  \"logging\": {\n    \"level\": \"${spec.logLevel}\"\n  }${_properties_block}\n}\n"
}

_build_default_config_file = lambda spec: ApplicationConfigSpec -> {str:str} {
    _file_name = _default_config_file_name(spec.runtime)
    _content = _build_toml_config(spec) if spec.runtime == "rust" else (_build_json_config(spec) if spec.runtime in ["vue", "nuxt", "angular", "react", "next"] else _build_yaml_like_config(spec))
    {"${_file_name}" = _content}
}

_build_runtime_env = lambda spec: ApplicationConfigSpec -> {str:str} {
    _base: {str:str} = {
        APP_NAME = spec.applicationName
        APP_ENVIRONMENT = spec.environment
        LOG_LEVEL = spec.logLevel
        if spec.port != Undefined:
            PORT = str(spec.port)
        if spec.apiBaseUrl:
            API_BASE_URL = spec.apiBaseUrl
        if spec.publicBaseUrl:
            PUBLIC_BASE_URL = spec.publicBaseUrl
    }
    _python: {str:str} = {
        PYTHONUNBUFFERED = "1"
    } if spec.runtime == "python" else {}
    _kotlin: {str:str} = {
        SPRING_APPLICATION_NAME = spec.applicationName
        SPRING_PROFILES_ACTIVE = spec.environment
        LOGGING_LEVEL_ROOT = spec.logLevel
        if spec.port != Undefined:
            SERVER_PORT = str(spec.port)
    } if spec.runtime == "kotlin" else {}
    _rust: {str:str} = {
        RUST_LOG = spec.logLevel
    } if spec.runtime == "rust" else {}
    _go: {str:str} = {
        GIN_MODE = "release" if spec.environment == "production" else "debug"
    } if spec.runtime == "go" else {}
    _vue: {str:str} = {
        if spec.apiBaseUrl:
            VITE_API_BASE_URL = spec.apiBaseUrl
        if spec.publicBaseUrl:
            VITE_PUBLIC_BASE_URL = spec.publicBaseUrl
    } if spec.runtime == "vue" else {}
    _nuxt: {str:str} = {
        if spec.apiBaseUrl:
            NUXT_PUBLIC_API_BASE_URL = spec.apiBaseUrl
        if spec.publicBaseUrl:
            NUXT_PUBLIC_BASE_URL = spec.publicBaseUrl
    } if spec.runtime == "nuxt" else {}
    _angular: {str:str} = {
        if spec.apiBaseUrl:
            NG_APP_API_BASE_URL = spec.apiBaseUrl
        if spec.publicBaseUrl:
            NG_APP_PUBLIC_BASE_URL = spec.publicBaseUrl
    } if spec.runtime == "angular" else {}
    _react: {str:str} = {
        if spec.apiBaseUrl:
            REACT_APP_API_BASE_URL = spec.apiBaseUrl
        if spec.publicBaseUrl:
            REACT_APP_PUBLIC_BASE_URL = spec.publicBaseUrl
    } if spec.runtime == "react" else {}
    _next: {str:str} = {
        if spec.apiBaseUrl:
            NEXT_PUBLIC_API_BASE_URL = spec.apiBaseUrl
        if spec.publicBaseUrl:
            NEXT_PUBLIC_BASE_URL = spec.publicBaseUrl
    } if spec.runtime == "next" else {}

    _base | _python | _kotlin | _rust | _go | _vue | _nuxt | _angular | _react | _next
}

build_config_data = lambda spec: ApplicationConfigSpec -> {str:str} {
    _defaults = _build_default_config_file(spec)
    _files = spec.configFiles if spec.configFiles else {}
    _extra_files = spec.extraConfigFiles if spec.extraConfigFiles else {}
    _defaults | _files | _extra_files
}

_env_map_to_list = lambda values: {str:str} -> [any] {
    [{name = key, value = env_value} for key, env_value in values]
}

_env_var_to_k8s = lambda env: EnvVar -> any {
    {
        name = env.name
        if env.value != Undefined:
            value = env.value
        if env.secretKeyRef != Undefined:
            valueFrom = {
                secretKeyRef = {
                    name = env.secretKeyRef.name
                    key = env.secretKeyRef.key
                }
            }
        if env.configMapKeyRef != Undefined:
            valueFrom = {
                configMapKeyRef = {
                    name = env.configMapKeyRef.name
                    key = env.configMapKeyRef.key
                }
            }
    }
}

build_env_map = lambda spec: ApplicationConfigSpec -> {str:str} {
    _generated = _build_runtime_env(spec)
    _env = spec.env if spec.env else {}
    _extra_env = spec.extraEnv if spec.extraEnv else {}
    _generated | _env | _extra_env
}

build_env_vars = lambda spec: ApplicationConfigSpec -> [any] {
    _direct = _env_map_to_list(build_env_map(spec))
    _custom = [_env_var_to_k8s(env) for env in (spec.envVars or [])]
    _secret = [_env_var_to_k8s(env) for env in (spec.secretEnvVars or [])]
    _direct + _custom + _secret
}

build_config_bundle = lambda spec: ApplicationConfigSpec -> any {
    {
        configData = build_config_data(spec)
        env = build_env_vars(spec)
    }
}




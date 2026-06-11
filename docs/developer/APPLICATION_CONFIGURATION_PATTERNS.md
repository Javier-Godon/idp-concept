# Application Configuration Patterns

Use `framework/custom/application_configurations.k` to generate standard ConfigMap file data and Kubernetes environment variables for common application runtimes.

The helper is designed for `WebAppModule`, which already accepts:

- `configData?: {str:str}`
- `env?: [any]`

Use these helpers in module definitions, then validate through the normal CLI loop:

```bash
koncept validate --factory <factory>
koncept render argocd --factory <factory>
koncept policy check --factory <factory>
```

## Supported runtimes

| Runtime | Default config file | Runtime-specific env examples |
|---|---|---|
| `python` | `config.yaml` | `PYTHONUNBUFFERED` |
| `go` | `config.yaml` | `GIN_MODE` |
| `rust` | `config.toml` | `RUST_LOG` |
| `kotlin` | `application.yaml` | `SPRING_PROFILES_ACTIVE`, `SERVER_PORT` |
| `vue` | `runtime-config.json` | `VITE_API_BASE_URL` |
| `nuxt` | `runtime-config.json` | `NUXT_PUBLIC_API_BASE_URL` |
| `angular` | `assets/config.json` | `NG_APP_API_BASE_URL` |
| `react` | `runtime-config.json` | `REACT_APP_API_BASE_URL` |
| `next` | `runtime-config.json` | `NEXT_PUBLIC_API_BASE_URL` |

## WebAppModule example

```kcl
import framework.templates.webapp.v1_0_0.webapp as webapp
import framework.custom.application_configurations as appcfg

_config = appcfg.build_config_bundle(appcfg.ApplicationConfigSpec {
    runtime = "next"
    applicationName = "customer-portal"
    environment = "stg"
    port = 3000
    apiBaseUrl = "https://api.stg.example.com"
    publicBaseUrl = "https://portal.stg.example.com"
    extraEnv = {
        FEATURE_FLAGS_ENABLED = "true"
    }
    extraConfigFiles = {
        "feature-flags.json" = "{\"newCheckout\": true}\n"
    }
    secretEnvVars = [appcfg.EnvVar {
        name = "API_TOKEN"
        secretKeyRef = appcfg.SecretKeySelector {
            name = "portal-secrets"
            key = "api-token"
        }
    }]
})

schema CustomerPortal(webapp.WebAppModule):
    port = 3000
    configData = _config.configData
    env = _config.env
```

## Override model

For files:

1. generated default file
2. `configFiles`
3. `extraConfigFiles` wins last

For environment variables:

1. generated runtime env
2. `env`
3. `extraEnv` wins last
4. `envVars` and `secretEnvVars` are appended for explicit/valueFrom entries

## Ad hoc configuration

Use `properties` and `extraProperties` for values that should be included in the generated default config file.

Use `extraConfigFiles` when your runtime needs additional files such as:

- `.env`
- `settings.py`
- `config.production.yaml`
- `appsettings.json`
- `feature-flags.json`
- frontend runtime config files

Use `extraEnv` for simple direct environment variables and `secretEnvVars` for values coming from Kubernetes Secrets.

## Safety Rules

- Put non-secret runtime values in `extraEnv`, `properties`, or generated config files.
- Put credentials, API tokens, passwords, and signing keys in `secretEnvVars`.
- Do not hardcode secret-looking values in `configData` or direct env values; policy checks are expected to flag them.
- Keep frontend public config values separate from server-side secrets, especially for `next`, `nuxt`, `react`, and `vue` runtimes.

"""
Spring Boot application.properties helper tests.

The helper should support standard Spring Boot properties and free-form overrides
without forcing team-specific defaults.
"""
import custom.spring_application_properties as sap

# === Test: standard Spring Boot sections ===
test_spring_properties_standard_sections = lambda {
    _props = sap.build_properties(sap.ApplicationProperties {
        applicationName = "orders"
        server = sap.ServerProperties {
            port = 8080
            compressionEnabled = True
        }
        spring = sap.SpringProperties {
            profilesActive = ["dev", "local"]
            datasource = sap.DatasourceProperties {
                url = "jdbc:postgresql://postgres:5432/orders"
                username = "orders"
                driverClassName = "org.postgresql.Driver"
                hikariMaximumPoolSize = 10
            }
            jpa = sap.JpaProperties {
                hibernateDdlAuto = "validate"
                openInView = False
            }
        }
        management = sap.ManagementProperties {
            endpointsWebExposureInclude = ["health", "info", "prometheus"]
            endpointHealthProbesEnabled = True
        }
    })

    assert _props["spring.application.name"] == "orders"
    assert _props["server.port"] == "8080"
    assert _props["server.compression.enabled"] == "true"
    assert _props["spring.profiles.active"] == "dev,local"
    assert _props["spring.datasource.url"] == "jdbc:postgresql://postgres:5432/orders"
    assert _props["spring.datasource.hikari.maximum-pool-size"] == "10"
    assert _props["spring.jpa.hibernate.ddl-auto"] == "validate"
    assert _props["spring.jpa.open-in-view"] == "false"
    assert _props["management.endpoints.web.exposure.include"] == "health,info,prometheus"
    assert _props["management.endpoint.health.probes.enabled"] == "true"
}

# === Test: extra properties override generated values ===
test_spring_properties_extra_overrides = lambda {
    _props = sap.build_properties(sap.ApplicationProperties {
        serverPort = 8080
        properties = {
            "server.port" = "8081"
            "feature.alpha.enabled" = "true"
        }
        extraProperties = {
            "server.port" = "9090"
        }
    })

    assert _props["server.port"] == "9090"
    assert _props["feature.alpha.enabled"] == "true"
}

# === Test: arbitrary Spring properties are supported ===
test_spring_properties_free_form_only = lambda {
    _props = sap.build_properties(sap.ApplicationProperties {
        extraProperties = {
            "spring.threads.virtual.enabled" = "true"
            "spring.docker.compose.enabled" = "false"
            "custom.team.property" = "kept"
        }
    })

    assert _props["spring.threads.virtual.enabled"] == "true"
    assert _props["spring.docker.compose.enabled"] == "false"
    assert _props["custom.team.property"] == "kept"
}

# === Test: single-property renderer ===
test_spring_properties_render_single_property = lambda {
    _rendered = sap.render_properties(sap.ApplicationProperties {
        extraProperties = {
            "spring.application.name" = "orders"
        }
    })

    assert _rendered == "spring.application.name=orders"
}

# === Test: legacy team-specific sections still map to properties ===
test_spring_properties_legacy_sections = lambda {
    _props = sap.build_properties(sap.ApplicationProperties {
        moduleSpring = sap.ModuleSpring {
            postgres = sap.SubModulePostgres {
                namespace = "postgres.data.svc.cluster.local"
                database = "orders"
                username = "orders"
                password = "configured-via-secret"
                testOnBorrow = True
            }
            oauth2Security = sap.SubModuleOauth2Security {
                providerUrl = "https://keycloak.example.com"
                realm = "platform"
            }
        }
        keycloak = sap.ModuleKeycloak {
            realm = "platform"
        }
    })

    assert _props["spring.datasource.url"] == "jdbc:postgresql://postgres.data.svc.cluster.local:5432/orders"
    assert _props["spring.datasource.username"] == "orders"
    assert _props["spring.datasource.test-on-borrow"] == "true"
    assert _props["spring.security.oauth2.resourceserver.jwt.issuer-uri"] == "https://keycloak.example.com/realms/platform"
    assert _props["keycloak.realm"] == "platform"
}

# === Test: legacy management schema is still accepted on `management` ===
test_spring_properties_legacy_management_field = lambda {
    _props = sap.build_properties(sap.ApplicationProperties {
        management = sap.ModuleManagement {
            serverPort = 9090
        }
    })

    assert _props["management.server.port"] == "9090"
    assert _props["management.security.enabled"] == "false"
    assert _props["management.endpoint.health.show-details"] == "always"
}





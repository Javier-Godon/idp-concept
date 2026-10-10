"""
Valkey Admin Template Tests — Deployment/Service, sub-path HTTPRoute, basic-auth SecurityPolicy,
the standalone module and the ValkeyModule/XValkeyInstance integration.
"""
import templates.valkey.v1_0_0.valkey as valkey
import templates.valkey.v1_0_0.valkey_admin as valkey_admin
import procedures.kcl_to_crossplane as crossplane_proc
import runtime

_va_spec = lambda extra: {str:} = {} -> valkey_admin.ValkeyAdminSpec {
    valkey_admin.ValkeyAdminSpec {
        name = "cache-admin"
        namespace = "data"
        valkeyHost = "cache.data.svc.cluster.local"
        **extra
    }
}

test_valkey_admin_internal_only = lambda {
    _r = valkey_admin.build_valkey_admin_resources(_va_spec())
    assert [m.kind for m in _r] == ["Deployment", "Service"]
    _c = _r[0].spec.template.spec.containers[0]
    assert _c.image == "valkey/valkey-admin:1.2.0"
    assert _r[0].spec.replicas == 1
    assert {e.name: e.value for e in _c.env}["VALKEY_HOST"] == "cache.data.svc.cluster.local"
    assert {e.name: e.value for e in _c.env}["DEPLOYMENT_MODE"] == "Web"
    assert "VALKEY_ADMIN_ALLOWED_WS_ORIGINS" not in {e.name: e.value for e in _c.env}
    assert _c.securityContext.allowPrivilegeEscalation == False
    assert _r[0].spec.template.spec.securityContext.runAsNonRoot == True
    assert _r[1].spec.ports[0].port == 8080
}

test_valkey_admin_published_on_subpath_with_basic_auth = lambda {
    _r = valkey_admin.build_valkey_admin_resources(_va_spec({
        hostname = "bluesolution.es"
        basicAuthSecretName = "valkey-admin-basic-auth"
    }))
    assert [m.kind for m in _r] == ["Deployment", "Service", "HTTPRoute", "SecurityPolicy"]
    _route = _r[2]
    assert _route.spec.hostnames == ["bluesolution.es"]
    assert _route.spec.parentRefs[0].sectionName == "https"
    assert _route.spec.rules[0].matches[0].path == {type = "Exact", value = "/valkey-admin"}
    assert _route.spec.rules[0].filters[0].requestRedirect.path.replaceFullPath == "/valkey-admin/"
    assert _route.spec.rules[1].matches[0].path == {type = "PathPrefix", value = "/valkey-admin"}
    assert _route.spec.rules[1].filters[0].urlRewrite.path.replacePrefixMatch == "/"
    assert _route.spec.rules[1].backendRefs == [{name = "cache-admin", port = 8080}]
    assert _r[3].spec.targetRefs[0] == {group = "gateway.networking.k8s.io", kind = "HTTPRoute", name = "cache-admin"}
    assert _r[3].spec.basicAuth.users.name == "valkey-admin-basic-auth"
    _env = {e.name: e.value for e in _r[0].spec.template.spec.containers[0].env}
    assert _env["VALKEY_ADMIN_ALLOWED_WS_ORIGINS"] == "https://bluesolution.es"
}

test_valkey_admin_password_comes_from_a_secret = lambda {
    _r = valkey_admin.build_valkey_admin_resources(_va_spec({passwordSecretName = "valkey-auth"}))
    _pw = [e for e in _r[0].spec.template.spec.containers[0].env if e.name == "VALKEY_PASSWORD"][0]
    assert _pw.valueFrom.secretKeyRef.name == "valkey-auth"
    assert _pw.valueFrom.secretKeyRef.key == "password"
}

test_valkey_admin_production_requires_basic_auth_when_published = lambda {
    _err = runtime.catch(lambda {
        _va_spec({footprint = "production", hostname = "bluesolution.es"})
    })
    assert _err != Undefined, "Expected validation error: published production UI without basic auth"
    assert _va_spec({footprint = "production"}).footprint == "production"
}

test_valkey_admin_rejects_unpinned_image_and_bad_path = lambda {
    assert runtime.catch(lambda {
        _va_spec({version = "latest"})
    }) != Undefined
    assert runtime.catch(lambda {
        _va_spec({path = "/valkey-admin/"})
    }) != Undefined
    assert runtime.catch(lambda {
        _va_spec({path = "valkey-admin"})
    }) != Undefined
}

test_valkey_admin_xr_spec = lambda {
    _xr = valkey_admin.build_valkey_admin_xr_spec(valkey_admin.ValkeyAdminOptions {
        hostname = "bluesolution.es"
        basicAuthSecretName = "valkey-admin-basic-auth"
    })
    assert _xr.image == "valkey/valkey-admin:1.2.0"
    assert _xr.hostname == "bluesolution.es"
    assert _xr.path == "/valkey-admin"
    assert _xr.listener == "https"
    assert _xr.basicAuthSecretName == "valkey-admin-basic-auth"
    _internal = valkey_admin.build_valkey_admin_xr_spec(valkey_admin.ValkeyAdminOptions {})
    assert "hostname" not in _internal
}

test_valkey_admin_url_has_trailing_slash = lambda {
    assert valkey_admin.admin_url("bluesolution.es", "/valkey-admin") == "https://bluesolution.es/valkey-admin/"
}

_va_standalone = valkey_admin.ValkeyAdminModule {
    name = "cache-admin"
    namespace = "data"
    configurations = {}
    asset = {version = "1.2.0"}
    dependsOn = []
    valkeyHost = "cache.data.svc.cluster.local"
    options = valkey_admin.ValkeyAdminOptions {hostname = "bluesolution.es"}
}.instance

test_valkey_admin_standalone_module = lambda {
    assert _va_standalone.kind == "INFRASTRUCTURE"
    assert [x.kind for x in _va_standalone.manifests] == ["Deployment", "Service", "HTTPRoute"]
    assert _va_standalone.manifests[0].spec.template.spec.containers[0].image == "valkey/valkey-admin:1.2.0"
}

_va_with_admin = valkey.ValkeyModule {
    name = "cache"
    namespace = "erp-data"
    configurations = {}
    asset = {version = "8.1.10"}
    dependsOn = []
    valkeyName = "cache"
    footprint = "development"
    valkeyAdmin = valkey_admin.ValkeyAdminOptions {
        hostname = "bluesolution.es"
        basicAuthSecretName = "valkey-admin-basic-auth"
    }
}.instance

test_valkey_module_emits_admin_manifests_and_xr_block = lambda {
    _m = _va_with_admin
    assert [x.kind for x in _m.manifests] == ["HelmRelease", "Deployment", "Service", "HTTPRoute", "SecurityPolicy"]
    # Bitnami chart primary Service for the YAML/Helm outputs.
    assert {e.name: e.value for e in _m.manifests[1].spec.template.spec.containers[0].env}["VALKEY_HOST"] == "cache-valkey-primary.erp-data.svc.cluster.local"
    assert _m.crossplaneSpec.adminUi.hostname == "bluesolution.es"
    assert _m.crossplaneSpec.adminUi.path == "/valkey-admin"
}

_va_without_admin = valkey.ValkeyModule {
    name = "cache"
    namespace = "erp-data"
    configurations = {}
    asset = {version = "8.1.10"}
    dependsOn = []
    valkeyName = "cache"
}.instance

test_valkey_module_without_admin_has_no_admin_block = lambda {
    _m = _va_without_admin
    assert [x.kind for x in _m.manifests] == ["HelmRelease"]
    assert "adminUi" not in _m.crossplaneSpec
}

test_crossplane_output_carries_admin_ui_in_the_xr = lambda {
    _out = crossplane_proc.generate_crossplane_from_stack([], [_va_with_admin], [], "erp", "0.1.0")
    assert len(_out.managed_resources) == 1
    assert _out.managed_resources[0].kind == "XValkeyInstance"
    assert _out.managed_resources[0].spec.adminUi.basicAuthSecretName == "valkey-admin-basic-auth"
    assert _out.metadata.resourceCount == 0
}

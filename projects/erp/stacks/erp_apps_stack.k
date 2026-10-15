"""
erp application workloads stack (Tier-1 GitOps YAML): the ERP API and its two admin UIs.

Rendered by the dev_apps pre-release with `koncept render argocd` and synced by the `erp-apps-dev`
Argo CD Application. Kept apart from ErpStack, whose curated data/identity services are rendered as
Crossplane XRs: application Deployments/Services are never wrapped in Crossplane objects.
"""

import framework.models.stack
import framework.models.compatibility as compat
import framework.assembly.helpers as asm
import erp.stacks.erp_stack as infra
import erp.modules.appops.erp_backend.erp_backend_module_def as erp_backend
import erp.modules.appops.erp_admin_ui.erp_admin_ui_module_def as erp_admin_ui

schema ErpAppsStack(stack.Stack):
    compatibility = compat.FrameworkCompatibility {
        version = "dev"
        versionConstraint = ">=0.1.0 <1.0.0"
        supportTier = "tier-1"
        source = "local"
        supportWindow = "until next minor framework release"
    }

    _apps_namespace = asm.create_namespace(instanceConfigurations.appsNamespace, instanceConfigurations)

    k8snamespaces = [_apps_namespace]

    _erp_backend = erp_backend.ErpBackendModule {
        name = "erp-backend"
        namespace = _apps_namespace.name
        asset = {
            image = instanceConfigurations.erpBackendImage
            version = instanceConfigurations.erpBackendVersion
        }
        keycloakServiceName = "${infra.KEYCLOAK_NAME}-service"
        configurations = instanceConfigurations
        dependsOn = [_apps_namespace]
    }.instance

    _erp_owner_admin = erp_admin_ui.ErpAdminUiModule {
        name = "erp-owner-admin"
        namespace = _apps_namespace.name
        asset = {
            image = instanceConfigurations.erpOwnerAdminImage
            version = instanceConfigurations.erpOwnerAdminVersion
        }
        basePath = instanceConfigurations.erpOwnerAdminPath
        oidcClientId = instanceConfigurations.erpOwnerAdminOidcClientId
        secretName = instanceConfigurations.erpOwnerAdminSecret
        caConfigMap = instanceConfigurations.platformCaConfigMap
        configurations = instanceConfigurations
        dependsOn = [_apps_namespace]
    }.instance

    _erp_tenant_admin = erp_admin_ui.ErpAdminUiModule {
        name = "erp-tenant-admin"
        namespace = _apps_namespace.name
        asset = {
            image = instanceConfigurations.erpTenantAdminImage
            version = instanceConfigurations.erpTenantAdminVersion
        }
        basePath = instanceConfigurations.erpTenantAdminPath
        oidcClientId = instanceConfigurations.erpTenantAdminOidcClientId
        secretName = instanceConfigurations.erpTenantAdminSecret
        caConfigMap = instanceConfigurations.platformCaConfigMap
        configurations = instanceConfigurations
        dependsOn = [_apps_namespace]
    }.instance

    components = [_erp_backend, _erp_owner_admin, _erp_tenant_admin]
    accessories = []

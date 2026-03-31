"""
ArgoCD procedure tests — validates ArgoCD Application generation from stack/release structures.
TDD: Phase 5 — kcl_to_argocd implementation.
"""
import procedures.kcl_to_argocd as argocd_proc
import models.modules.component as component
import models.modules.accessory as accessory
import models.stack as stack

# === Helper: minimal component ===
_test_component = component.ComponentInstance {
    name = "api"
    kind = "APPLICATION"
    namespace = "apps"
    configurations = {}
    asset = { version = "1.0.0" }
    leaders = [{ name = "api", kind = "Deployment", apiVersion = "apps/v1" }]
    manifests = [
        { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "api" } }
    ]
    dependsOn = []
}

_test_component_2 = component.ComponentInstance {
    name = "worker"
    kind = "APPLICATION"
    namespace = "apps"
    configurations = {}
    asset = { version = "2.0.0" }
    leaders = [{ name = "worker", kind = "Deployment", apiVersion = "apps/v1" }]
    manifests = [
        { apiVersion = "apps/v1", kind = "Deployment", metadata = { name = "worker" } }
    ]
    dependsOn = []
}

# === Test: generate single ArgoCD Application from component ===
test_generate_application = lambda {
    _app = argocd_proc.generate_application(
        _test_component
        "my-project"
        "https://github.com/org/repo"
        "HEAD"
        "projects/my-project/output"
        "apps"
    )
    assert _app.apiVersion == "argoproj.io/v1alpha1"
    assert _app.kind == "Application"
    assert _app.metadata.name == "api"
    assert _app.metadata.namespace == "argocd"
    assert _app.spec.project == "my-project"
    assert _app.spec.source.repoURL == "https://github.com/org/repo"
    assert _app.spec.source.targetRevision == "HEAD"
    assert _app.spec.source.path == "projects/my-project/output"
    assert _app.spec.destination.server == "https://kubernetes.default.svc"
    assert _app.spec.destination.namespace == "apps"
}

# === Test: generate applications for all stack components ===
test_generate_applications_from_stack = lambda {
    _test_stack = stack.Stack {
        instanceConfigurations = {}
        components = [_test_component, _test_component_2]
    }
    _apps = argocd_proc.generate_applications_from_stack(
        _test_stack
        "my-project"
        "https://github.com/org/repo"
        "HEAD"
        "projects/my-project/output"
    )
    assert len(_apps) == 2
    assert _apps[0].metadata.name == "api"
    assert _apps[1].metadata.name == "worker"
    # Each app targets its own component namespace
    assert _apps[0].spec.destination.namespace == "apps"
    assert _apps[1].spec.destination.namespace == "apps"
}

# === Test: generate AppProject ===
test_generate_app_project = lambda {
    _proj = argocd_proc.generate_app_project(
        "my-project"
        "my-project"
        ["https://github.com/org/repo"]
        ["apps", "infra"]
    )
    assert _proj.apiVersion == "argoproj.io/v1alpha1"
    assert _proj.kind == "AppProject"
    assert _proj.metadata.name == "my-project"
    assert _proj.metadata.namespace == "argocd"
    assert _proj.spec.sourceRepos[0] == "https://github.com/org/repo"
    assert len(_proj.spec.destinations) == 2
    assert _proj.spec.destinations[0].namespace == "apps"
    assert _proj.spec.destinations[0].server == "https://kubernetes.default.svc"
}

# === Test: empty stack produces empty list ===
test_generate_applications_empty_stack = lambda {
    _test_stack = stack.Stack {
        instanceConfigurations = {}
        components = []
    }
    _apps = argocd_proc.generate_applications_from_stack(
        _test_stack
        "my-project"
        "https://github.com/org/repo"
        "HEAD"
        "output"
    )
    assert len(_apps) == 0
}

# === Test: generate_applications_from_stack accepts GitOpsStack-like (any type) ===
test_generate_applications_any_type = lambda {
    # Simulate a reduced stack with only some components (like GitOpsStack)
    _mini = {
        components = [_test_component]
    }
    _apps = argocd_proc.generate_applications_from_stack(
        _mini
        "proj"
        "https://github.com/org/repo"
        "main"
        "output"
    )
    assert len(_apps) == 1
    assert _apps[0].spec.source.targetRevision == "main"
}

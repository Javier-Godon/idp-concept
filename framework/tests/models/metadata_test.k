"""
Core IDP metadata model tests.
"""
import runtime
import models.metadata as meta
import models.compatibility as compat
import models.project as project
import models.tenant as tenant
import models.profile as profile
import models.site as site
import models.stack as stack
import models.modules.component as component

_empty_config = {}

# === Test: Metadata carries common IDP/catalog fields ===
test_metadata_common_fields = lambda {
    _metadata = meta.Metadata {
        displayName = "Orders API"
        owner = "team-platform"
        system = "erp"
        domain = "commerce"
        lifecycle = "production"
        tier = "tier-1"
        criticality = "high"
        costCenter = "cc-1234"
        repository = "https://github.com/example/orders"
        documentation = "https://docs.example.com/orders"
        support = "https://support.example.com/orders"
        tags = ["api", "backend"]
        labels = {
            app = "orders"
        }
        annotations = {
            "backstage.io/source-location" = "url:https://github.com/example/orders"
        }
        links = [meta.Link {
            title = "Runbook"
            url = "https://docs.example.com/orders/runbook"
        }]
        contacts = [meta.Contact {
            email = "team-platform@example.com"
        }]
    }

    assert _metadata.owner == "team-platform"
    assert _metadata.tags[0] == "api"
    assert _metadata.links[0].title == "Runbook"
    assert _metadata.contacts[0].email == "team-platform@example.com"
}

# === Test: Invalid link is rejected ===
test_metadata_link_rejects_empty_url = lambda {
    _err = runtime.catch(lambda {
        meta.Link {
            title = "Docs"
            url = ""
        }
    })
    assert _err != Undefined, "expected empty link URL to be rejected"
}

# === Test: Invalid contact is rejected ===
test_metadata_contact_requires_value = lambda {
    _err = runtime.catch(lambda {
        meta.Contact {}
    })
    assert _err != Undefined, "expected empty contact to be rejected"
}

# === Test: Project metadata is copied to instance ===
test_project_metadata_instance = lambda {
    _project = project.Project {
        name = "ERP Back"
        description = "ERP backend"
        metadata = meta.Metadata {
            owner = "team-erp"
            lifecycle = "production"
        }
        configurations = _empty_config
    }

    assert _project.instance.metadata.owner == "team-erp"
    assert _project.instance.metadata.lifecycle == "production"
}

# === Test: Tenant metadata is copied to instance ===
test_tenant_metadata_instance = lambda {
    _tenant = tenant.Tenant {
        name = "Internal"
        description = "Internal tenant"
        metadata = meta.Metadata {
            owner = "platform"
        }
        configurations = _empty_config
    }

    assert _tenant.instance.metadata.owner == "platform"
}

# === Test: Profile metadata is copied to instance ===
test_profile_metadata_instance = lambda {
    _profile = profile.Profile {
        name = "staging"
        metadata = meta.Metadata {
            lifecycle = "staging"
        }
        configurations = _empty_config
    }

    assert _profile.instance.metadata.lifecycle == "staging"
}

# === Test: Site metadata is copied to instance ===
test_site_metadata_instance = lambda {
    _tenant = tenant.Tenant {
        name = "Internal"
        description = "Internal tenant"
        configurations = _empty_config
    }
    _site = site.Site {
        name = "stg-cluster"
        tenant = _tenant
        metadata = meta.Metadata {
            domain = "eu-west"
        }
        configurations = _empty_config
    }

    assert _site.instance.metadata.domain == "eu-west"
}

# === Test: Stack metadata is copied to instance ===
test_stack_metadata_instance = lambda {
    _component = component.Component {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = _empty_config
        asset = component.ComponentAsset {
            image = "example/api"
            version = "1.0.0"
        }
        leaders = []
        manifests = []
        dependsOn = []
    }.instance

    _stack = stack.Stack {
        instanceConfigurations = _empty_config
        metadata = meta.Metadata {
            tags = ["blue-green"]
        }
        components = [_component]
    }

    assert _stack.instance.metadata.tags[0] == "blue-green"
}

# === Test: Stack compatibility is copied to instance ===
test_stack_compatibility_instance = lambda {
    _component = component.Component {
        name = "api"
        kind = "APPLICATION"
        namespace = "apps"
        configurations = _empty_config
        asset = component.ComponentAsset {
            image = "example/api"
            version = "1.0.0"
        }
        leaders = []
        manifests = []
        dependsOn = []
    }.instance

    _stack = stack.Stack {
        instanceConfigurations = _empty_config
        compatibility = compat.FrameworkCompatibility {
            version = "0.2.0"
            versionConstraint = ">=0.2.0 <0.3.0"
            supportTier = "tier-1"
        }
        components = [_component]
    }

    assert _stack.instance.compatibility.version == "0.2.0"
    assert _stack.instance.compatibility.supportTier == "tier-1"
}


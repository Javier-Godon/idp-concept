"""
Tests for BaseConfigurations gitRepoUrl field (Phase 1.2).
Validates that git repo URL can be set and merges correctly.
"""
import models.configurations as cfg

# === Test: BaseConfigurations accepts gitRepoUrl ===
test_base_config_git_repo_url = lambda {
    _cfg = cfg.BaseConfigurations {
        projectName = "test"
        gitRepoUrl = "https://github.com/org/repo"
    }
    assert _cfg.gitRepoUrl == "https://github.com/org/repo"
}

# === Test: gitRepoUrl is optional ===
test_base_config_git_repo_url_optional = lambda {
    _cfg = cfg.BaseConfigurations {
        projectName = "test"
    }
    assert _cfg.gitRepoUrl is Undefined
}

# === Test: gitRepoUrl merges via site override ===
test_git_repo_url_merge_override = lambda {
    _kernel = { projectName = "test", gitRepoUrl = "https://github.com/org/default" }
    _profile = {}
    _tenant = {}
    _site = { gitRepoUrl = "https://github.com/fork/repo" }

    _result = cfg.merge_configurations(_kernel, _profile, _tenant, _site)
    assert _result.gitRepoUrl == "https://github.com/fork/repo"
}

# === Test: gitRepoUrl preserved when not overridden ===
test_git_repo_url_merge_preserve = lambda {
    _kernel = { projectName = "test", gitRepoUrl = "https://github.com/org/repo" }
    _profile = {}
    _tenant = {}
    _site = { siteName = "prod" }

    _result = cfg.merge_configurations(_kernel, _profile, _tenant, _site)
    assert _result.gitRepoUrl == "https://github.com/org/repo"
}

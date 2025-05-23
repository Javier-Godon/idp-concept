[package]
name = "releases"
edition = "v0.10.0"
version = "0.0.1"

[dependencies]
framework = { path = "../../../framework" }
kernel = { path = "../kernel" }
sites = { path = "../sites" }
stacks = { path = "../stacks" }
tenants = { path = "../tenants" }
core_sources = { path = "../core_sources" }


[profile]
entries = ["../sites/tenants/production/berlin/config.yaml"]

[package]
name = "v1_0_0_berlin"
edition = "v0.10.0"
version = "0.0.1"

[dependencies]
kam = { git = "https://github.com/KusionStack/kam.git", tag = "0.2.0" }
network = { oci = "oci://ghcr.io/kusionstack/network", tag = "0.2.0" }
service = { oci = "oci://ghcr.io/kusionstack/service", tag = "0.1.0" }
releases = { path = "../../../../../releases" }

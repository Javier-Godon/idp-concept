[package]
name = "test_to_delete"
edition = "v0.10.0"
version = "0.0.1"

[dependencies]
k8s = "1.31.2"

[profile]
entries = [
   "schema_test.k", "schema_test2.k", "schema_test3.k"
]

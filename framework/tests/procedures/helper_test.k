import procedures.helper as h

# === Test: Extract models by name ===
test_extract_models_by_name = lambda {
    _models = [
        { name = "app1", port = 8080 }
        { name = "app2", port = 9090 }
        { name = "app1", port = 3000 }
    ]
    _result = h.extract_models_by_name_from_list(_models, "app1")
    assert len(_result) == 2
    assert _result[0].port == 8080
    assert _result[1].port == 3000
}

# === Test: Extract models no match ===
test_extract_models_no_match = lambda {
    _models = [
        { name = "app1", port = 8080 }
    ]
    _result = h.extract_models_by_name_from_list(_models, "nonexistent")
    assert len(_result) == 0
}

# === Test: Extract models empty list ===
test_extract_models_empty_list = lambda {
    _result = h.extract_models_by_name_from_list([], "any")
    assert len(_result) == 0
}

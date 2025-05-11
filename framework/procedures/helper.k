extract_models_by_name_from_list = lambda models: [any], name: str -> [any] {
    [model for model in models if model.name == name]
}

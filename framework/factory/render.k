"""
Generic multi-format renderer wrapper.

Project factories can mirror this short wrapper and delegate all render logic to
framework.factory.render_entry.render_from_seed.
"""
import framework.factory.render_entry as render_entry
import .factory_seed as factory_ctx

_output = option("output", default="yaml")

render_entry.render_from_seed(
	factory_ctx._stack
	factory_ctx._project_name
	factory_ctx._git_repo_url
	factory_ctx._manifest_path
	_output
)

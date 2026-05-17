"""Backward-compatible Opentelemetry template wrapper.

The implementation lives in `templates.opentelemetry.main`. Keep this root module thin so
existing imports such as `import templates.opentelemetry as opentelemetry` continue to work
without duplicating template implementation code.
"""

import templates.opentelemetry.main as opentelemetry_compat

OtelOperatorSpec = opentelemetry_compat.OtelOperatorSpec
build_otel_operator = opentelemetry_compat.build_otel_operator
OtelCollectorSpec = opentelemetry_compat.OtelCollectorSpec
build_otel_collector = opentelemetry_compat.build_otel_collector
InstrumentationSpec = opentelemetry_compat.InstrumentationSpec
build_instrumentation = opentelemetry_compat.build_instrumentation

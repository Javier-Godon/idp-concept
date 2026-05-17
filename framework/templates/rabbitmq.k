"""Backward-compatible Rabbitmq template wrapper.

The implementation lives in `templates.rabbitmq.main`. Keep this root module thin so
existing imports such as `import templates.rabbitmq as rabbitmq` continue to work
without duplicating template implementation code.
"""

import templates.rabbitmq.main as rabbitmq_compat

RabbitMQClusterSpec = rabbitmq_compat.RabbitMQClusterSpec
build_rabbitmq_cluster = rabbitmq_compat.build_rabbitmq_cluster
RabbitMQClusterModule = rabbitmq_compat.RabbitMQClusterModule

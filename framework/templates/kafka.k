"""Backward-compatible Kafka template wrapper.

The implementation lives in `templates.kafka.main`. Keep this root module thin so
existing imports such as `import templates.kafka as kafka` continue to work
without duplicating template implementation code.
"""

import templates.kafka.main as kafka_compat

KafkaTopicSpec = kafka_compat.KafkaTopicSpec
KafkaClusterModule = kafka_compat.KafkaClusterModule

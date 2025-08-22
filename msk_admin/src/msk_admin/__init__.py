"""MSK Admin - Production-grade Python tool for managing Amazon MSK (Kafka) control-plane tasks."""

__version__ = "0.1.0"
__author__ = "MSK Admin Team"

from .kafka_admin import KafkaAdmin
from .schema_registry import SchemaRegistry
from .config import Settings

__all__ = ["KafkaAdmin", "SchemaRegistry", "Settings"]

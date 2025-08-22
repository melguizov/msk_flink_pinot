"""CLI interface for MSK Admin using Typer."""

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Any

import typer
import structlog
from rich.console import Console
from rich.table import Table
from rich.json import JSON
from rich.panel import Panel

from .config import get_settings
from .kafka_admin import KafkaAdmin, KafkaAdminError
from .schema_registry import SchemaRegistry, SchemaRegistryError
from .topic_profiles import list_profiles, get_performance_notes

# Initialize Typer app
app = typer.Typer(
    name="msk-admin",
    help="Production-grade Python tool for managing Amazon MSK (Kafka) control-plane tasks",
    no_args_is_help=True
)

# Create sub-commands
topics_app = typer.Typer(help="Kafka topic management commands")
schema_app = typer.Typer(help="AWS Glue Schema Registry commands")

app.add_typer(topics_app, name="topics")
app.add_typer(schema_app, name="schema")

# Rich console for pretty output
console = Console()

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)


def handle_error(error: Exception, operation: str) -> None:
    """Handle and display errors consistently."""
    error_data = {
        "status": "error",
        "operation": operation,
        "error": str(error),
        "error_type": type(error).__name__
    }
    
    console.print(JSON(json.dumps(error_data, indent=2)))
    sys.exit(1)


def print_success(data: Dict[str, Any]) -> None:
    """Print successful operation results as JSON."""
    result = {"status": "success", **data}
    console.print(JSON(json.dumps(result, indent=2, default=str)))


# Topic Management Commands
@topics_app.command("create")
def create_topic(
    name: str = typer.Argument(..., help="Topic name"),
    partitions: Optional[int] = typer.Option(None, "--partitions", "-p", help="Number of partitions"),
    replication: Optional[int] = typer.Option(None, "--replication", "-r", help="Replication factor"),
    profile: str = typer.Option("general_throughput", "--profile", help="Topic configuration profile"),
    config: Optional[List[str]] = typer.Option(None, "--config", "-c", help="Config overrides (key=value)")
) -> None:
    """Create a new Kafka topic with specified configuration."""
    try:
        settings = get_settings()
        admin = KafkaAdmin(settings)
        
        # Parse config overrides
        config_overrides = {}
        if config:
            for cfg in config:
                if "=" not in cfg:
                    raise typer.BadParameter(f"Config must be in key=value format: {cfg}")
                key, value = cfg.split("=", 1)
                config_overrides[key.strip()] = value.strip()
        
        admin.create_topic(
            name=name,
            partitions=partitions,
            replication_factor=replication,
            config=config_overrides,
            profile=profile
        )
        
        print_success({
            "operation": "create_topic",
            "topic": name,
            "partitions": partitions or settings.default_partitions,
            "replication_factor": replication or settings.default_replication_factor,
            "profile": profile,
            "config_overrides": config_overrides
        })
        
    except (KafkaAdminError, Exception) as e:
        handle_error(e, "create_topic")


@topics_app.command("list")
def list_topics() -> None:
    """List all Kafka topics."""
    try:
        settings = get_settings()
        admin = KafkaAdmin(settings)
        
        topics = admin.list_topics()
        
        print_success({
            "operation": "list_topics",
            "topics": topics,
            "count": len(topics)
        })
        
    except (KafkaAdminError, Exception) as e:
        handle_error(e, "list_topics")


@topics_app.command("describe")
def describe_topic(
    name: str = typer.Argument(..., help="Topic name")
) -> None:
    """Describe a Kafka topic."""
    try:
        settings = get_settings()
        admin = KafkaAdmin(settings)
        
        topic_info = admin.describe_topic(name)
        
        print_success({
            "operation": "describe_topic",
            **topic_info
        })
        
    except (KafkaAdminError, Exception) as e:
        handle_error(e, "describe_topic")


@topics_app.command("alter-config")
def alter_topic_config(
    name: str = typer.Argument(..., help="Topic name"),
    config: List[str] = typer.Option(..., "--config", "-c", help="Config changes (key=value)")
) -> None:
    """Alter topic configuration."""
    try:
        settings = get_settings()
        admin = KafkaAdmin(settings)
        
        # Parse config changes
        config_changes = {}
        for cfg in config:
            if "=" not in cfg:
                raise typer.BadParameter(f"Config must be in key=value format: {cfg}")
            key, value = cfg.split("=", 1)
            config_changes[key.strip()] = value.strip()
        
        admin.alter_topic_config(name, config_changes)
        
        print_success({
            "operation": "alter_topic_config",
            "topic": name,
            "config_changes": config_changes
        })
        
    except (KafkaAdminError, Exception) as e:
        handle_error(e, "alter_topic_config")


@topics_app.command("delete")
def delete_topic(
    name: str = typer.Argument(..., help="Topic name"),
    confirm: bool = typer.Option(False, "--confirm", help="Skip confirmation prompt")
) -> None:
    """Delete a Kafka topic."""
    try:
        if not confirm:
            confirmed = typer.confirm(f"Are you sure you want to delete topic '{name}'?")
            if not confirmed:
                console.print("Operation cancelled.")
                return
        
        settings = get_settings()
        admin = KafkaAdmin(settings)
        
        admin.delete_topic(name)
        
        print_success({
            "operation": "delete_topic",
            "topic": name
        })
        
    except (KafkaAdminError, Exception) as e:
        handle_error(e, "delete_topic")


@topics_app.command("profiles")
def show_profiles() -> None:
    """Show available topic configuration profiles."""
    try:
        profiles = list_profiles()
        performance_notes = get_performance_notes()
        
        result = {
            "operation": "show_profiles",
            "profiles": {}
        }
        
        for profile_name, description in profiles.items():
            result["profiles"][profile_name] = {
                "description": description,
                "performance": performance_notes.get(profile_name, {})
            }
        
        print_success(result)
        
    except Exception as e:
        handle_error(e, "show_profiles")


# Schema Registry Commands
@schema_app.command("register")
def register_schema(
    file: str = typer.Option(..., "--file", "-f", help="Path to Avro schema file"),
    name: str = typer.Option(..., "--name", "-n", help="Schema name"),
    compat: str = typer.Option("BACKWARD", "--compat", help="Compatibility mode")
) -> None:
    """Register an Avro schema in AWS Glue Schema Registry."""
    try:
        schema_path = Path(file)
        if not schema_path.exists():
            raise typer.BadParameter(f"Schema file not found: {file}")
        
        schema_content = schema_path.read_text()
        
        settings = get_settings()
        registry = SchemaRegistry(settings)
        
        schema_arn = registry.register_avro_schema(
            schema_str=schema_content,
            schema_name=name,
            compatibility=compat
        )
        
        print_success({
            "operation": "register_schema",
            "schema_name": name,
            "schema_arn": schema_arn,
            "compatibility": compat,
            "file": file
        })
        
    except (SchemaRegistryError, Exception) as e:
        handle_error(e, "register_schema")


@schema_app.command("get")
def get_schema(
    name: str = typer.Option(..., "--name", "-n", help="Schema name"),
    version: Optional[int] = typer.Option(None, "--version", "-v", help="Schema version")
) -> None:
    """Get schema definition from AWS Glue Schema Registry."""
    try:
        settings = get_settings()
        registry = SchemaRegistry(settings)
        
        schema_definition = registry.get_schema(name, version)
        
        print_success({
            "operation": "get_schema",
            "schema_name": name,
            "version": version,
            "schema_definition": json.loads(schema_definition)
        })
        
    except (SchemaRegistryError, Exception) as e:
        handle_error(e, "get_schema")


@schema_app.command("list")
def list_schemas() -> None:
    """List all schemas in the registry."""
    try:
        settings = get_settings()
        registry = SchemaRegistry(settings)
        
        schemas = registry.list_schemas()
        
        print_success({
            "operation": "list_schemas",
            "schemas": schemas,
            "count": len(schemas)
        })
        
    except (SchemaRegistryError, Exception) as e:
        handle_error(e, "list_schemas")


@schema_app.command("check-compatibility")
def check_compatibility(
    name: str = typer.Option(..., "--name", "-n", help="Schema name"),
    file: str = typer.Option(..., "--file", "-f", help="Path to candidate schema file")
) -> None:
    """Check if a candidate schema is compatible with existing schema."""
    try:
        schema_path = Path(file)
        if not schema_path.exists():
            raise typer.BadParameter(f"Schema file not found: {file}")
        
        candidate_schema = schema_path.read_text()
        
        settings = get_settings()
        registry = SchemaRegistry(settings)
        
        is_compatible = registry.check_compatibility(name, candidate_schema)
        
        print_success({
            "operation": "check_compatibility",
            "schema_name": name,
            "candidate_file": file,
            "compatible": is_compatible
        })
        
    except (SchemaRegistryError, Exception) as e:
        handle_error(e, "check_compatibility")


@schema_app.command("versions")
def list_schema_versions(
    name: str = typer.Option(..., "--name", "-n", help="Schema name")
) -> None:
    """List all versions of a schema."""
    try:
        settings = get_settings()
        registry = SchemaRegistry(settings)
        
        versions = registry.get_schema_versions(name)
        
        print_success({
            "operation": "list_schema_versions",
            "schema_name": name,
            "versions": versions,
            "count": len(versions)
        })
        
    except (SchemaRegistryError, Exception) as e:
        handle_error(e, "list_schema_versions")


# Health Check Command
@app.command("health")
def health_check() -> None:
    """Perform a health check on the Kafka cluster."""
    try:
        settings = get_settings()
        admin = KafkaAdmin(settings)
        
        health_result = admin.health_check()
        
        print_success({
            "operation": "health_check",
            **health_result
        })
        
    except Exception as e:
        handle_error(e, "health_check")


# Configuration Command
@app.command("config")
def show_config() -> None:
    """Show current configuration."""
    try:
        settings = get_settings()
        
        # Mask sensitive information
        config_dict = settings.dict()
        sensitive_fields = ['kafka_sasl_password', 'ssl_key_location']
        
        for field in sensitive_fields:
            if field in config_dict and config_dict[field]:
                config_dict[field] = "***MASKED***"
        
        print_success({
            "operation": "show_config",
            "configuration": config_dict
        })
        
    except Exception as e:
        handle_error(e, "show_config")


# Version Command
@app.command("version")
def show_version() -> None:
    """Show version information."""
    from . import __version__
    
    print_success({
        "operation": "show_version",
        "version": __version__,
        "name": "msk-admin"
    })


if __name__ == "__main__":
    app()

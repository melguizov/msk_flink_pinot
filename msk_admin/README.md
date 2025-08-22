# MSK Admin

Production-grade Python tool for managing Amazon MSK (Kafka) control-plane tasks.

## Features

- **Topic Management**: Create, list, describe, alter, and delete Kafka topics
- **Performance Profiles**: Pre-configured topic settings optimized for different use cases
- **Schema Registry**: Register, get, and evolve AWS Glue Schema Registry schemas (Avro)
- **Multi-Auth Support**: TLS, SASL/SCRAM, and SASL/IAM (OAUTHBEARER) authentication
- **Clean CLI & SDK**: Both command-line interface and importable Python SDK
- **Local Development**: No EC2 assumptions, runs locally with proper AWS credentials

## Quick Start

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd msk-admin

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -e .
```

### Configuration

Copy the example environment file and configure your settings:

```bash
cp .env.example .env
# Edit .env with your MSK cluster details
```

### Basic Usage

```bash
# Health check
msk-admin health

# List topics
msk-admin topics list

# Create a topic with default profile
msk-admin topics create my-topic --partitions 6 --replication 3

# Create a topic with low-latency profile
msk-admin topics create fast-topic --profile low_latency

# Register an Avro schema
msk-admin schema register --file schemas/flight_weather.avsc --name flight_weather_v1

# List schemas
msk-admin schema list
```

## Authentication Matrix

| Security Protocol | SASL Mechanism | Required Environment Variables |
|-------------------|----------------|-------------------------------|
| SSL | - | `SSL_CA_LOCATION`, `SSL_CERT_LOCATION`, `SSL_KEY_LOCATION` |
| SASL_SSL | SCRAM-SHA-512 | `KAFKA_SASL_USERNAME`, `KAFKA_SASL_PASSWORD` |
| SASL_SSL | OAUTHBEARER | AWS credentials (IAM role/user with MSK permissions) |

### TLS Authentication Example

```bash
export KAFKA_SECURITY_PROTOCOL=SSL
export SSL_CA_LOCATION=/path/to/ca-cert.pem
export SSL_CERT_LOCATION=/path/to/client-cert.pem
export SSL_KEY_LOCATION=/path/to/client-key.pem
```

### SCRAM Authentication Example

```bash
export KAFKA_SECURITY_PROTOCOL=SASL_SSL
export KAFKA_SASL_MECHANISM=SCRAM-SHA-512
export KAFKA_SASL_USERNAME=your-username
export KAFKA_SASL_PASSWORD=your-password
```

### IAM Authentication Example

```bash
export KAFKA_SECURITY_PROTOCOL=SASL_SSL
export KAFKA_SASL_MECHANISM=OAUTHBEARER
# AWS credentials via environment, IAM role, or AWS CLI profile
```

## Topic Configuration Profiles

| Profile | Use Case | Throughput | Latency | Durability | Storage |
|---------|----------|------------|---------|------------|---------|
| `general_throughput` | Most production workloads | High | Medium | High | Medium (3 days) |
| `low_latency` | Real-time applications | Medium | Low | Medium | Low (1 day) |
| `compaction_log` | State stores, CDC | Medium | Medium | High | Variable |
| `long_retention` | Audit logs, compliance | Medium | Medium-High | High | High (14 days) |

### Profile Details

#### general_throughput (Default)
- **Retention**: 3 days with snappy compression
- **Segments**: 1-hour or 1GB segments for efficient compaction
- **Durability**: `min.insync.replicas=2`, no unclean leader elections
- **Best for**: Event streaming, general messaging

#### low_latency
- **Retention**: 1 day with lz4 compression (fastest)
- **Segments**: 30-minute segments for faster leader election
- **Durability**: `min.insync.replicas=1` for faster writes
- **Best for**: Trading systems, IoT, real-time analytics

#### compaction_log
- **Cleanup**: Log compaction enabled with 50% dirty ratio
- **Retention**: Optimized for key-based data with tombstone handling
- **Best for**: Kafka Streams state stores, change data capture

#### long_retention
- **Retention**: 14 days with zstd compression (best ratio)
- **Segments**: 24-hour/2GB segments for storage efficiency
- **Best for**: Audit trails, compliance data, data lake ingestion

## CLI Commands

### Topic Management

```bash
# Create topic with custom configuration
msk-admin topics create my-topic \
  --partitions 12 \
  --replication 3 \
  --profile general_throughput \
  --config retention.ms=604800000 \
  --config compression.type=zstd

# List all topics
msk-admin topics list

# Describe topic details
msk-admin topics describe my-topic

# Alter topic configuration
msk-admin topics alter-config my-topic \
  --config retention.ms=1209600000 \
  --config segment.ms=7200000

# Delete topic (with confirmation)
msk-admin topics delete my-topic

# Show available profiles
msk-admin topics profiles
```

### Schema Registry

```bash
# Register Avro schema
msk-admin schema register \
  --file schemas/user_event.avsc \
  --name user_event_v1 \
  --compat BACKWARD

# Get schema definition
msk-admin schema get --name user_event_v1

# List all schemas
msk-admin schema list

# Check schema compatibility
msk-admin schema check-compatibility \
  --name user_event_v1 \
  --file schemas/user_event_v2.avsc

# List schema versions
msk-admin schema versions --name user_event_v1
```

### Utility Commands

```bash
# Health check
msk-admin health

# Show current configuration
msk-admin config

# Show version
msk-admin version
```

## Python SDK Usage

```python
from msk_admin import KafkaAdmin, SchemaRegistry, Settings

# Initialize with custom settings
settings = Settings(
    aws_region="us-west-2",
    msk_cluster_arn="arn:aws:kafka:us-west-2:123456789012:cluster/my-cluster/...",
    kafka_security_protocol="SASL_SSL",
    kafka_sasl_mechanism="OAUTHBEARER"
)

# Topic management
admin = KafkaAdmin(settings)

# Create topic with profile
admin.create_topic(
    name="events",
    partitions=6,
    replication_factor=3,
    profile="general_throughput",
    config={"retention.ms": "259200000"}
)

# List topics
topics = admin.list_topics()

# Schema registry operations
registry = SchemaRegistry(settings)

# Register schema
schema_arn = registry.register_avro_schema(
    schema_str=avro_schema_json,
    schema_name="user_events_v1",
    compatibility="BACKWARD"
)

# Get schema
schema_def = registry.get_schema("user_events_v1")
```

## Development

### Setup Development Environment

```bash
# Install development dependencies
pip install -e ".[dev]"

# Install pre-commit hooks
pre-commit install

# Run tests
make test

# Run linting
make lint

# Format code
make format
```

### Project Structure

```
msk-admin/
├── src/msk_admin/
│   ├── __init__.py          # Package initialization
│   ├── config.py            # Pydantic settings and bootstrap resolution
│   ├── kafka_admin.py       # Kafka AdminClient operations
│   ├── topic_profiles.py    # Performance-focused topic configurations
│   ├── schema_registry.py   # AWS Glue Schema Registry operations
│   ├── iam_oauth.py         # IAM SASL authentication
│   └── cli.py              # Typer CLI interface
├── schemas/                 # Example Avro schemas
├── tests/                   # Test suite
├── pyproject.toml          # Project configuration
├── README.md               # This file
├── .env.example            # Environment variables template
├── Dockerfile              # Container image
└── Makefile               # Development commands
```

## Troubleshooting

### Common Issues

#### Bootstrap Server Connection Failed
- **Cause**: Incorrect bootstrap servers or network connectivity
- **Solution**: Verify `MSK_CLUSTER_ARN` or `KAFKA_BOOTSTRAP` setting
- **Check**: Security groups allow traffic on Kafka ports (9092, 9094, 9096)

#### Authentication Failed
- **SCRAM**: Verify username/password and that SCRAM is enabled on cluster
- **IAM**: Ensure AWS credentials have `kafka-cluster:Connect` permissions
- **TLS**: Check certificate paths and validity

#### Topic Creation Failed
- **Cause**: Insufficient permissions or invalid configuration
- **Solution**: Verify IAM permissions include `kafka:CreateTopic`
- **Check**: Replication factor doesn't exceed available brokers

#### Schema Registry Access Denied
- **Cause**: Missing Glue permissions
- **Solution**: Add `glue:RegisterSchemaVersion`, `glue:GetSchema` permissions
- **Check**: Registry name exists and is accessible

### Network Configuration

MSK clusters require specific security group rules:

```
Inbound Rules:
- Port 9092 (PLAINTEXT) - if using PLAINTEXT
- Port 9094 (TLS) - if using SSL/TLS
- Port 9096 (SASL) - if using SASL authentication

Outbound Rules:
- All traffic to 0.0.0.0/0 (or specific MSK subnets)
```

### Performance Tuning

#### High Throughput Workloads
- Use `general_throughput` or custom profile
- Increase `batch.size` and `linger.ms` on producers
- Consider `compression.type=snappy` for balanced performance

#### Low Latency Workloads
- Use `low_latency` profile
- Reduce `segment.ms` for faster log rolling
- Use `compression.type=lz4` for fastest compression

#### Long-term Storage
- Use `long_retention` profile
- Consider `compression.type=zstd` for best compression ratio
- Increase `segment.bytes` to reduce metadata overhead

## Security Best Practices

1. **Never log sensitive credentials**
2. **Use IAM roles instead of access keys when possible**
3. **Enable encryption in transit and at rest**
4. **Regularly rotate SCRAM credentials**
5. **Use least-privilege IAM policies**
6. **Monitor cluster access logs**

## License

MIT License - see LICENSE file for details.

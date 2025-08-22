# Flight Data Producer

A Python application that fetches real-time flight data from the Aviation Stack API, converts it to Avro format, and publishes it to a Kafka topic every 10 minutes.

## Features

✅ **Aviation Stack API Integration**: Fetches real-time flight data  
✅ **Avro Serialization**: Complete Avro schema with Schema Registry support  
✅ **Confluent Kafka Producer**: Reliable message delivery  
✅ **Scheduled Execution**: Runs every 10 minutes (configurable)  
✅ **Comprehensive Data Model**: 40+ fields including departure, arrival, airline, aircraft, live tracking  
✅ **Error Handling**: Robust error handling with logging and retry mechanisms  
✅ **Flexible Configuration**: Environment variables and command-line arguments  
✅ **Production Ready**: Delivery reports, proper resource cleanup, authentication support  

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

Copy the example environment file and update with your settings:

```bash
cp .env.example .env
# Edit .env with your specific configuration
```

### 3. Run the Producer

**Single execution:**
```bash
python get_flights.py
```

**Continuous execution (every 10 minutes):**
```bash
python get_flights.py --continuous
```

**Custom interval:**
```bash
python get_flights.py --continuous --interval 5  # Every 5 minutes
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AVIATION_STACK_API_KEY` | `19bc4f835d687e9fe187b873848f3d5e` | Aviation Stack API key |
| `AVIATION_STACK_API_URL` | `https://api.aviationstack.com/v1/flights` | API endpoint |
| `KAFKA_BROKERS` | `localhost:9092` | Kafka broker addresses |
| `KAFKA_TOPIC` | `flight-data` | Kafka topic name |
| `SCHEMA_REGISTRY_URL` | `http://localhost:8081` | Schema Registry URL |
| `FETCH_INTERVAL_MINUTES` | `10` | Fetch interval in minutes |
| `MAX_FLIGHTS_PER_REQUEST` | `100` | Max flights per API request |

### Command Line Arguments

```bash
python get_flights.py --help
```

- `--continuous`: Run continuously with scheduled fetching
- `--interval N`: Fetch interval in minutes (default: 10)
- `--api-key KEY`: Aviation Stack API key (overrides env var)
- `--kafka-brokers BROKERS`: Kafka brokers (overrides env var)
- `--kafka-topic TOPIC`: Kafka topic (overrides env var)

## Data Schema

The producer converts Aviation Stack API responses to a comprehensive Avro schema including:

### Flight Information
- `flight_date`: Flight date
- `flight_status`: Current flight status
- `timestamp`: Processing timestamp
- `producer_id`: Producer identifier

### Departure Details
- Airport information (name, IATA/ICAO codes, timezone)
- Terminal and gate information
- Scheduled, estimated, and actual times
- Runway times and delays

### Arrival Details
- Airport information (name, IATA/ICAO codes, timezone)
- Terminal, gate, and baggage information
- Scheduled, estimated, and actual times
- Runway times and delays

### Airline Information
- Airline name and codes (IATA/ICAO)

### Flight Details
- Flight numbers and codes (IATA/ICAO)
- Codeshare information

### Aircraft Information
- Aircraft registration and codes
- ICAO24 identifier

### Live Tracking (when available)
- GPS coordinates (latitude/longitude)
- Altitude and direction
- Horizontal and vertical speed
- Ground status

## Architecture

### Components

1. **FlightConfig**: Configuration management with environment variable support
2. **FlightDataProducer**: Main producer class handling API calls and Kafka publishing
3. **Avro Schema**: Comprehensive schema for flight data serialization
4. **Scheduler**: Built-in scheduling for continuous operation

### Error Handling

- **API Failures**: Retry logic with exponential backoff
- **Schema Validation**: Graceful handling of missing or invalid data
- **Kafka Failures**: Delivery reports and retry mechanisms
- **Graceful Shutdown**: Proper resource cleanup on interruption

### Monitoring

- **Structured Logging**: Comprehensive logging for debugging and monitoring
- **Delivery Reports**: Kafka message delivery confirmation
- **Error Tracking**: Detailed error reporting and handling

## Integration

### With Kafka Ecosystem

- **Schema Registry**: Automatic schema registration and evolution
- **Confluent Platform**: Full compatibility with Confluent Kafka
- **Apache Kafka**: Works with standard Apache Kafka installations

### With AWS MSK

Configure for Amazon Managed Streaming for Apache Kafka:

```bash
export KAFKA_BROKERS="your-msk-cluster-endpoint:9092"
export SCHEMA_REGISTRY_URL="your-schema-registry-endpoint:8081"
```

### With EKS/Kubernetes

Deploy as a Kubernetes CronJob or Deployment for scheduled execution.

## Production Deployment

### Docker

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["python", "get_flights.py", "--continuous"]
```

### Kubernetes CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: flight-data-producer
spec:
  schedule: "*/10 * * * *"  # Every 10 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: flight-producer
            image: flight-data-producer:latest
            env:
            - name: KAFKA_BROKERS
              value: "kafka-service:9092"
            - name: KAFKA_TOPIC
              value: "flight-data"
          restartPolicy: OnFailure
```

## Troubleshooting

### Common Issues

1. **API Key Issues**: Ensure your Aviation Stack API key is valid and has sufficient quota
2. **Kafka Connection**: Verify Kafka brokers are accessible and topic exists
3. **Schema Registry**: Check if Schema Registry is running (optional but recommended)
4. **Network Issues**: Ensure outbound internet access for API calls

### Debugging

Enable debug logging:

```python
import logging
logging.getLogger().setLevel(logging.DEBUG)
```

### Health Checks

The producer logs successful operations and errors. Monitor logs for:
- API fetch success/failure
- Data transformation issues
- Kafka publishing status
- Schema validation errors

## License

This project is part of the MSK-Flink-Pinot streaming data pipeline.

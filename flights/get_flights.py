#!/usr/bin/env python3
"""
Flight Data Producer for Aviation Stack API

This script fetches real-time flight data from Aviation Stack API,
converts it to Avro format, and publishes to Kafka topic every 10 minutes.
"""

import os
import sys
import json
import time
import logging
import argparse
import requests
import schedule
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

import fastavro
import io
# from kafka import KafkaProducer  # Temporarily disabled due to Python 3.13 compatibility issues

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class FlightConfig:
    """Configuration for flight data producer"""
    api_key: str
    api_url: str = "https://api.aviationstack.com/v1/flights"
    kafka_brokers: str = "localhost:9092"
    kafka_topic: str = "flight-data"
    schema_registry_url: str = "http://localhost:8081"
    fetch_interval_minutes: int = 10
    max_flights_per_request: int = 100
    
    @classmethod
    def from_env(cls) -> 'FlightConfig':
        """Create configuration from environment variables"""
        return cls(
            api_key=os.getenv('AVIATION_STACK_API_KEY', '19bc4f835d687e9fe187b873848f3d5e'),
            api_url=os.getenv('AVIATION_STACK_API_URL', 'https://api.aviationstack.com/v1/flights'),
            kafka_brokers=os.getenv('KAFKA_BROKERS', 'localhost:9092'),
            kafka_topic=os.getenv('KAFKA_TOPIC', 'flight-data'),
            schema_registry_url=os.getenv('SCHEMA_REGISTRY_URL', 'http://localhost:8081'),
            fetch_interval_minutes=int(os.getenv('FETCH_INTERVAL_MINUTES', '10')),
            max_flights_per_request=int(os.getenv('MAX_FLIGHTS_PER_REQUEST', '100'))
        )

# Avro schema for flight data
FLIGHT_AVRO_SCHEMA = """
{
  "type": "record",
  "name": "FlightData",
  "namespace": "com.aviation.flights",
  "fields": [
    {"name": "flight_date", "type": ["null", "string"], "default": null},
    {"name": "flight_status", "type": ["null", "string"], "default": null},
    {"name": "departure", "type": {
      "type": "record",
      "name": "Departure",
      "fields": [
        {"name": "airport", "type": ["null", "string"], "default": null},
        {"name": "timezone", "type": ["null", "string"], "default": null},
        {"name": "iata", "type": ["null", "string"], "default": null},
        {"name": "icao", "type": ["null", "string"], "default": null},
        {"name": "terminal", "type": ["null", "string"], "default": null},
        {"name": "gate", "type": ["null", "string"], "default": null},
        {"name": "delay", "type": ["null", "int"], "default": null},
        {"name": "scheduled", "type": ["null", "string"], "default": null},
        {"name": "estimated", "type": ["null", "string"], "default": null},
        {"name": "actual", "type": ["null", "string"], "default": null},
        {"name": "estimated_runway", "type": ["null", "string"], "default": null},
        {"name": "actual_runway", "type": ["null", "string"], "default": null}
      ]
    }},
    {"name": "arrival", "type": {
      "type": "record",
      "name": "Arrival",
      "fields": [
        {"name": "airport", "type": ["null", "string"], "default": null},
        {"name": "timezone", "type": ["null", "string"], "default": null},
        {"name": "iata", "type": ["null", "string"], "default": null},
        {"name": "icao", "type": ["null", "string"], "default": null},
        {"name": "terminal", "type": ["null", "string"], "default": null},
        {"name": "gate", "type": ["null", "string"], "default": null},
        {"name": "baggage", "type": ["null", "string"], "default": null},
        {"name": "delay", "type": ["null", "int"], "default": null},
        {"name": "scheduled", "type": ["null", "string"], "default": null},
        {"name": "estimated", "type": ["null", "string"], "default": null},
        {"name": "actual", "type": ["null", "string"], "default": null},
        {"name": "estimated_runway", "type": ["null", "string"], "default": null},
        {"name": "actual_runway", "type": ["null", "string"], "default": null}
      ]
    }},
    {"name": "airline", "type": {
      "type": "record",
      "name": "Airline",
      "fields": [
        {"name": "name", "type": ["null", "string"], "default": null},
        {"name": "iata", "type": ["null", "string"], "default": null},
        {"name": "icao", "type": ["null", "string"], "default": null}
      ]
    }},
    {"name": "flight", "type": {
      "type": "record",
      "name": "Flight",
      "fields": [
        {"name": "number", "type": ["null", "string"], "default": null},
        {"name": "iata", "type": ["null", "string"], "default": null},
        {"name": "icao", "type": ["null", "string"], "default": null},
        {"name": "codeshared", "type": ["null", {
          "type": "record",
          "name": "Codeshared",
          "fields": [
            {"name": "airline_name", "type": ["null", "string"], "default": null},
            {"name": "airline_iata", "type": ["null", "string"], "default": null},
            {"name": "airline_icao", "type": ["null", "string"], "default": null},
            {"name": "flight_number", "type": ["null", "string"], "default": null},
            {"name": "flight_iata", "type": ["null", "string"], "default": null},
            {"name": "flight_icao", "type": ["null", "string"], "default": null}
          ]
        }], "default": null}
      ]
    }},
    {"name": "aircraft", "type": {
      "type": "record",
      "name": "Aircraft",
      "fields": [
        {"name": "registration", "type": ["null", "string"], "default": null},
        {"name": "iata", "type": ["null", "string"], "default": null},
        {"name": "icao", "type": ["null", "string"], "default": null},
        {"name": "icao24", "type": ["null", "string"], "default": null}
      ]
    }},
    {"name": "live", "type": ["null", {
      "type": "record",
      "name": "Live",
      "fields": [
        {"name": "updated", "type": ["null", "string"], "default": null},
        {"name": "latitude", "type": ["null", "double"], "default": null},
        {"name": "longitude", "type": ["null", "double"], "default": null},
        {"name": "altitude", "type": ["null", "double"], "default": null},
        {"name": "direction", "type": ["null", "double"], "default": null},
        {"name": "speed_horizontal", "type": ["null", "double"], "default": null},
        {"name": "speed_vertical", "type": ["null", "double"], "default": null},
        {"name": "is_ground", "type": ["null", "boolean"], "default": null}
      ]
    }], "default": null},
    {"name": "timestamp", "type": "string"},
    {"name": "producer_id", "type": "string"}
  ]
}
"""

class FlightDataProducer:
    """Flight data producer that fetches from Aviation Stack API and publishes to Kafka"""
    
    def __init__(self, config: FlightConfig):
        self.config = config
        self.schema = json.loads(FLIGHT_AVRO_SCHEMA)
        
        # Initialize Kafka producer (temporarily disabled due to Python 3.13 compatibility)
        self.producer = None
        logger.warning("Kafka producer disabled - will save data to file instead")
        # try:
        #     self.producer = KafkaProducer(
        #         bootstrap_servers=config.kafka_brokers.split(','),
        #         client_id='flight-data-producer',
        #         retries=5,
        #         acks='all',
        #         compression_type='gzip',
        #         value_serializer=self._serialize_avro
        #     )
        #     logger.info(f"Initialized Kafka producer with brokers: {config.kafka_brokers}")
        #     
        # except Exception as e:
        #     logger.error(f"Failed to initialize Kafka producer: {e}")
        #     raise
    
    def _serialize_avro(self, data: Dict[str, Any]) -> bytes:
        """Serialize data to Avro format"""
        try:
            bytes_writer = io.BytesIO()
            fastavro.schemaless_writer(bytes_writer, self.schema, data)
            return bytes_writer.getvalue()
        except Exception as e:
            logger.error(f"Failed to serialize data to Avro: {e}")
            # Fallback to JSON serialization
            return json.dumps(data).encode('utf-8')
    
    def fetch_flight_data(self) -> Optional[List[Dict[str, Any]]]:
        """Fetch flight data from Aviation Stack API"""
        try:
            params = {
                'access_key': self.config.api_key,
                'limit': self.config.max_flights_per_request
            }
            
            logger.info(f"Fetching flight data from {self.config.api_url}")
            response = requests.get(self.config.api_url, params=params, timeout=60)
            response.raise_for_status()
            
            data = response.json()
            
            if 'data' not in data:
                logger.error(f"Unexpected API response format: {data}")
                return None
            
            flights = data['data']
            logger.info(f"Successfully fetched {len(flights)} flights")
            return flights
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to fetch flight data: {e}")
            return None
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse API response: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error fetching flight data: {e}")
            return None
    
    def transform_flight_data(self, flight_data: Dict[str, Any]) -> Dict[str, Any]:
        """Transform API response to match Avro schema"""
        def safe_get(data: Dict, key: str, default=None):
            """Safely get value from dict, handling None values"""
            value = data.get(key, default)
            return value if value is not None else default
        
        # Transform departure data
        departure_raw = safe_get(flight_data, 'departure', {})
        departure = {
            'airport': safe_get(departure_raw, 'airport'),
            'timezone': safe_get(departure_raw, 'timezone'),
            'iata': safe_get(departure_raw, 'iata'),
            'icao': safe_get(departure_raw, 'icao'),
            'terminal': safe_get(departure_raw, 'terminal'),
            'gate': safe_get(departure_raw, 'gate'),
            'delay': safe_get(departure_raw, 'delay'),
            'scheduled': safe_get(departure_raw, 'scheduled'),
            'estimated': safe_get(departure_raw, 'estimated'),
            'actual': safe_get(departure_raw, 'actual'),
            'estimated_runway': safe_get(departure_raw, 'estimated_runway'),
            'actual_runway': safe_get(departure_raw, 'actual_runway')
        }
        
        # Transform arrival data
        arrival_raw = safe_get(flight_data, 'arrival', {})
        arrival = {
            'airport': safe_get(arrival_raw, 'airport'),
            'timezone': safe_get(arrival_raw, 'timezone'),
            'iata': safe_get(arrival_raw, 'iata'),
            'icao': safe_get(arrival_raw, 'icao'),
            'terminal': safe_get(arrival_raw, 'terminal'),
            'gate': safe_get(arrival_raw, 'gate'),
            'baggage': safe_get(arrival_raw, 'baggage'),
            'delay': safe_get(arrival_raw, 'delay'),
            'scheduled': safe_get(arrival_raw, 'scheduled'),
            'estimated': safe_get(arrival_raw, 'estimated'),
            'actual': safe_get(arrival_raw, 'actual'),
            'estimated_runway': safe_get(arrival_raw, 'estimated_runway'),
            'actual_runway': safe_get(arrival_raw, 'actual_runway')
        }
        
        # Transform airline data
        airline_raw = safe_get(flight_data, 'airline', {})
        airline = {
            'name': safe_get(airline_raw, 'name'),
            'iata': safe_get(airline_raw, 'iata'),
            'icao': safe_get(airline_raw, 'icao')
        }
        
        # Transform flight data
        flight_raw = safe_get(flight_data, 'flight', {})
        codeshared_raw = safe_get(flight_raw, 'codeshared')
        codeshared = None
        if codeshared_raw:
            codeshared = {
                'airline_name': safe_get(codeshared_raw, 'airline_name'),
                'airline_iata': safe_get(codeshared_raw, 'airline_iata'),
                'airline_icao': safe_get(codeshared_raw, 'airline_icao'),
                'flight_number': safe_get(codeshared_raw, 'flight_number'),
                'flight_iata': safe_get(codeshared_raw, 'flight_iata'),
                'flight_icao': safe_get(codeshared_raw, 'flight_icao')
            }
        
        flight = {
            'number': safe_get(flight_raw, 'number'),
            'iata': safe_get(flight_raw, 'iata'),
            'icao': safe_get(flight_raw, 'icao'),
            'codeshared': codeshared
        }
        
        # Transform aircraft data
        aircraft_raw = safe_get(flight_data, 'aircraft', {})
        aircraft = {
            'registration': safe_get(aircraft_raw, 'registration'),
            'iata': safe_get(aircraft_raw, 'iata'),
            'icao': safe_get(aircraft_raw, 'icao'),
            'icao24': safe_get(aircraft_raw, 'icao24')
        }
        
        # Transform live data
        live_raw = safe_get(flight_data, 'live')
        live = None
        if live_raw:
            live = {
                'updated': safe_get(live_raw, 'updated'),
                'latitude': safe_get(live_raw, 'latitude'),
                'longitude': safe_get(live_raw, 'longitude'),
                'altitude': safe_get(live_raw, 'altitude'),
                'direction': safe_get(live_raw, 'direction'),
                'speed_horizontal': safe_get(live_raw, 'speed_horizontal'),
                'speed_vertical': safe_get(live_raw, 'speed_vertical'),
                'is_ground': safe_get(live_raw, 'is_ground')
            }
        
        # Create the final transformed record
        transformed = {
            'flight_date': safe_get(flight_data, 'flight_date'),
            'flight_status': safe_get(flight_data, 'flight_status'),
            'departure': departure,
            'arrival': arrival,
            'airline': airline,
            'flight': flight,
            'aircraft': aircraft,
            'live': live,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'producer_id': 'flight-data-producer'
        }
        
        return transformed
    
    def publish_to_kafka(self, flight_records: List[Dict[str, Any]]) -> bool:
        """Publish flight records to Kafka topic (or save to file for testing)"""
        try:
            published_count = 0
            
            if self.producer is None:
                # Save to file for testing when Kafka is not available
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_file = f"flight_data_{timestamp}.json"
                
                logger.info(f"Kafka not available, saving {len(flight_records)} records to {output_file}")
                
                # Save as JSON for inspection
                with open(output_file, 'w') as f:
                    json.dump(flight_records, f, indent=2, default=str)
                
                # Also save as Avro for testing serialization
                avro_file = f"flight_data_{timestamp}.avro"
                try:
                    with open(avro_file, 'wb') as f:
                        fastavro.writer(f, self.schema, flight_records)
                    logger.info(f"Successfully saved Avro data to {avro_file}")
                except Exception as e:
                    logger.error(f"Failed to save Avro data: {e}")
                
                return True
            
            # Original Kafka publishing code (when producer is available)
            futures = []
            
            for record in flight_records:
                try:
                    # Create a unique key for each flight
                    airline_iata = record.get('airline', {}).get('iata') or 'UNKNOWN'
                    flight_number = record.get('flight', {}).get('number') or 'UNKNOWN'
                    flight_date = record.get('flight_date') or 'UNKNOWN'
                    key = f"{airline_iata}_{flight_number}_{flight_date}"
                    
                    # Send message to Kafka (value_serializer handles Avro serialization)
                    future = self.producer.send(
                        self.config.kafka_topic,
                        key=key.encode('utf-8'),
                        value=record
                    )
                    futures.append(future)
                    published_count += 1
                    
                except Exception as e:
                    logger.error(f"Failed to publish flight record: {e}")
                    continue
            
            # Wait for all messages to be delivered
            for future in futures:
                try:
                    record_metadata = future.get(timeout=30)
                    logger.debug(f'Message delivered to {record_metadata.topic} [{record_metadata.partition}]')
                except Exception as e:
                    logger.error(f'Message delivery failed: {e}')
            
            logger.info(f"Successfully published {published_count} flight records to topic '{self.config.kafka_topic}'")
            return published_count > 0
            
        except Exception as e:
            logger.error(f"Failed to publish to Kafka: {e}")
            return False
    
    def fetch_and_publish(self) -> bool:
        """Fetch flight data and publish to Kafka"""
        logger.info("Starting flight data fetch and publish cycle")
        
        # Fetch flight data from API
        flight_data = self.fetch_flight_data()

        print("----------",flight_data,"----------")
        
        if not flight_data:
            logger.warning("No flight data retrieved, skipping publish")
            return False
        
        # Transform data to match Avro schema
        transformed_records = []
        for flight in flight_data:
            try:
                transformed = self.transform_flight_data(flight)
                transformed_records.append(transformed)
            except Exception as e:
                logger.error(f"Failed to transform flight record: {e}")
                continue
        
        if not transformed_records:
            logger.warning("No valid flight records after transformation")
            return False
        
        # Publish to Kafka
        success = self.publish_to_kafka(transformed_records)
        
        if success:
            logger.info(f"Successfully completed fetch and publish cycle with {len(transformed_records)} records")
        else:
            logger.error("Failed to complete fetch and publish cycle")
        
        return success
    
    def start_scheduled_producer(self):
        """Start the scheduled flight data producer"""
        logger.info(f"Starting scheduled flight data producer (interval: {self.config.fetch_interval_minutes} minutes)")
        
        # Schedule the job
        schedule.every(self.config.fetch_interval_minutes).minutes.do(self.fetch_and_publish)
        
        # Run once immediately
        self.fetch_and_publish()
        
        # Keep running scheduled jobs
        try:
            while True:
                schedule.run_pending()
                time.sleep(60)  # Check every minute
        except KeyboardInterrupt:
            logger.info("Received interrupt signal, shutting down...")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Clean up resources"""
        if hasattr(self, 'producer') and self.producer is not None:
            self.producer.close()
            logger.info("Kafka producer cleaned up")

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Flight Data Producer')
    parser.add_argument('--continuous', action='store_true', 
                       help='Run continuously with scheduled fetching')
    parser.add_argument('--interval', type=int, default=10,
                       help='Fetch interval in minutes (default: 10)')
    parser.add_argument('--api-key', type=str,
                       help='Aviation Stack API key (overrides env var)')
    parser.add_argument('--kafka-brokers', type=str,
                       help='Kafka brokers (overrides env var)')
    parser.add_argument('--kafka-topic', type=str,
                       help='Kafka topic (overrides env var)')
    
    args = parser.parse_args()
    
    # Load configuration
    config = FlightConfig.from_env()
    
    # Override with command line arguments
    if args.api_key:
        config.api_key = args.api_key
    if args.kafka_brokers:
        config.kafka_brokers = args.kafka_brokers
    if args.kafka_topic:
        config.kafka_topic = args.kafka_topic
    if args.interval:
        config.fetch_interval_minutes = args.interval
    
    # Validate required configuration
    if not config.api_key:
        logger.error("Aviation Stack API key is required. Set AVIATION_STACK_API_KEY environment variable or use --api-key")
        sys.exit(1)
    
    # Create and run producer
    producer = FlightDataProducer(config)
    
    if args.continuous:
        producer.start_scheduled_producer()
    else:
        # Run once
        success = producer.fetch_and_publish()
        sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
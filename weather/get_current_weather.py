#!/usr/bin/env python3
"""
Weather Data Producer for OpenWeatherMap API

This script fetches real-time weather data from OpenWeatherMap API,
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
class WeatherConfig:
    """Configuration for weather data producer"""
    api_key: str
    api_url: str = "http://api.openweathermap.org/data/2.5/weather"
    kafka_brokers: str = "localhost:9092"
    kafka_topic: str = "weather-data"
    fetch_interval_minutes: int = 10
    cities: List[str] = None
    
    def __post_init__(self):
        if self.cities is None:
            # Major cities with high air traffic
            self.cities = [
                "Atlanta", "London", "Dubai", "Chicago", "Los Angeles", 
                "Tokyo", "Paris", "Dallas", "Beijing", "Frankfurt",
                "Amsterdam", "Istanbul", "Madrid", "Bangkok", "Singapore",
                "New York", "Miami", "Sydney", "Mumbai", "Toronto"
            ]
    
    @classmethod
    def from_env(cls) -> 'WeatherConfig':
        """Create configuration from environment variables"""
        cities_str = os.getenv('WEATHER_CITIES', '')
        cities = cities_str.split(',') if cities_str else None
        
        return cls(
            api_key=os.getenv('OPENWEATHER_API_KEY', '161761ef364b60cb644b81383f2830ac'),
            api_url=os.getenv('OPENWEATHER_API_URL', 'http://api.openweathermap.org/data/2.5/weather'),
            kafka_brokers=os.getenv('KAFKA_BROKERS', 'localhost:9092'),
            kafka_topic=os.getenv('KAFKA_TOPIC', 'weather-data'),
            fetch_interval_minutes=int(os.getenv('FETCH_INTERVAL_MINUTES', '10')),
            cities=cities
        )

# Avro schema for weather data
WEATHER_AVRO_SCHEMA = """
{
  "type": "record",
  "name": "WeatherData",
  "namespace": "com.weather.data",
  "fields": [
    {"name": "city", "type": "string"},
    {"name": "country", "type": ["null", "string"], "default": null},
    {"name": "coordinates", "type": {
      "type": "record",
      "name": "Coordinates",
      "fields": [
        {"name": "longitude", "type": "double"},
        {"name": "latitude", "type": "double"}
      ]
    }},
    {"name": "weather", "type": {
      "type": "record",
      "name": "Weather",
      "fields": [
        {"name": "main", "type": ["null", "string"], "default": null},
        {"name": "description", "type": ["null", "string"], "default": null},
        {"name": "icon", "type": ["null", "string"], "default": null}
      ]
    }},
    {"name": "main", "type": {
      "type": "record",
      "name": "MainWeather",
      "fields": [
        {"name": "temperature", "type": "double"},
        {"name": "feels_like", "type": ["null", "double"], "default": null},
        {"name": "temp_min", "type": ["null", "double"], "default": null},
        {"name": "temp_max", "type": ["null", "double"], "default": null},
        {"name": "pressure", "type": ["null", "int"], "default": null},
        {"name": "humidity", "type": ["null", "int"], "default": null},
        {"name": "sea_level", "type": ["null", "int"], "default": null},
        {"name": "grnd_level", "type": ["null", "int"], "default": null}
      ]
    }},
    {"name": "visibility", "type": ["null", "int"], "default": null},
    {"name": "wind", "type": ["null", {
      "type": "record",
      "name": "Wind",
      "fields": [
        {"name": "speed", "type": ["null", "double"], "default": null},
        {"name": "deg", "type": ["null", "int"], "default": null},
        {"name": "gust", "type": ["null", "double"], "default": null}
      ]
    }], "default": null},
    {"name": "clouds", "type": ["null", {
      "type": "record",
      "name": "Clouds",
      "fields": [
        {"name": "all", "type": ["null", "int"], "default": null}
      ]
    }], "default": null},
    {"name": "rain", "type": ["null", {
      "type": "record",
      "name": "Rain",
      "fields": [
        {"name": "one_hour", "type": ["null", "double"], "default": null},
        {"name": "three_hours", "type": ["null", "double"], "default": null}
      ]
    }], "default": null},
    {"name": "snow", "type": ["null", {
      "type": "record",
      "name": "Snow",
      "fields": [
        {"name": "one_hour", "type": ["null", "double"], "default": null},
        {"name": "three_hours", "type": ["null", "double"], "default": null}
      ]
    }], "default": null},
    {"name": "dt", "type": "long"},
    {"name": "sys", "type": {
      "type": "record",
      "name": "Sys",
      "fields": [
        {"name": "type", "type": ["null", "int"], "default": null},
        {"name": "id", "type": ["null", "int"], "default": null},
        {"name": "country", "type": ["null", "string"], "default": null},
        {"name": "sunrise", "type": ["null", "long"], "default": null},
        {"name": "sunset", "type": ["null", "long"], "default": null}
      ]
    }},
    {"name": "timezone", "type": ["null", "int"], "default": null},
    {"name": "id", "type": "long"},
    {"name": "timestamp", "type": "string"},
    {"name": "producer_id", "type": "string"}
  ]
}
"""

class WeatherDataProducer:
    """Weather data producer that fetches from OpenWeatherMap API and publishes to Kafka"""
    
    def __init__(self, config: WeatherConfig):
        self.config = config
        self.schema = json.loads(WEATHER_AVRO_SCHEMA)
        
        # Initialize Kafka producer (temporarily disabled due to Python 3.13 compatibility)
        self.producer = None
        logger.warning("Kafka producer disabled - will save data to file instead")
        # try:
        #     self.producer = KafkaProducer(
        #         bootstrap_servers=config.kafka_brokers.split(','),
        #         client_id='weather-data-producer',
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
    
    def fetch_weather_data(self) -> Optional[List[Dict[str, Any]]]:
        """Fetch weather data from OpenWeatherMap API for all cities"""
        weather_records = []
        
        for city in self.config.cities:
            try:
                params = {
                    'q': city,
                    'appid': self.config.api_key,
                    'units': 'metric'
                }
                
                logger.info(f"Fetching weather data for {city}")
                response = requests.get(self.config.api_url, params=params, timeout=30)
                response.raise_for_status()
                
                data = response.json()
                
                if data.get('cod') != 200:
                    logger.error(f"API error for {city}: {data.get('message', 'Unknown error')}")
                    continue
                
                weather_records.append(data)
                
            except requests.exceptions.RequestException as e:
                logger.error(f"Failed to fetch weather data for {city}: {e}")
                continue
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse API response for {city}: {e}")
                continue
            except Exception as e:
                logger.error(f"Unexpected error fetching weather data for {city}: {e}")
                continue
        
        if weather_records:
            logger.info(f"Successfully fetched weather data for {len(weather_records)} cities")
        
        return weather_records if weather_records else None
    
    def transform_weather_data(self, weather_data: Dict[str, Any]) -> Dict[str, Any]:
        """Transform API response to match Avro schema"""
        def safe_get(data: Dict, key: str, default=None):
            """Safely get value from dict, handling None values"""
            value = data.get(key, default)
            return value if value is not None else default
        
        # Transform coordinates
        coord_raw = safe_get(weather_data, 'coord', {})
        coordinates = {
            'longitude': safe_get(coord_raw, 'lon', 0.0),
            'latitude': safe_get(coord_raw, 'lat', 0.0)
        }
        
        # Transform weather info
        weather_list = safe_get(weather_data, 'weather', [])
        weather_info = weather_list[0] if weather_list else {}
        weather = {
            'main': safe_get(weather_info, 'main'),
            'description': safe_get(weather_info, 'description'),
            'icon': safe_get(weather_info, 'icon')
        }
        
        # Transform main weather data
        main_raw = safe_get(weather_data, 'main', {})
        main = {
            'temperature': safe_get(main_raw, 'temp', 0.0),
            'feels_like': safe_get(main_raw, 'feels_like'),
            'temp_min': safe_get(main_raw, 'temp_min'),
            'temp_max': safe_get(main_raw, 'temp_max'),
            'pressure': safe_get(main_raw, 'pressure'),
            'humidity': safe_get(main_raw, 'humidity'),
            'sea_level': safe_get(main_raw, 'sea_level'),
            'grnd_level': safe_get(main_raw, 'grnd_level')
        }
        
        # Transform wind data
        wind_raw = safe_get(weather_data, 'wind')
        wind = None
        if wind_raw:
            wind = {
                'speed': safe_get(wind_raw, 'speed'),
                'deg': safe_get(wind_raw, 'deg'),
                'gust': safe_get(wind_raw, 'gust')
            }
        
        # Transform clouds data
        clouds_raw = safe_get(weather_data, 'clouds')
        clouds = None
        if clouds_raw:
            clouds = {
                'all': safe_get(clouds_raw, 'all')
            }
        
        # Transform rain data
        rain_raw = safe_get(weather_data, 'rain')
        rain = None
        if rain_raw:
            rain = {
                'one_hour': safe_get(rain_raw, '1h'),
                'three_hours': safe_get(rain_raw, '3h')
            }
        
        # Transform snow data
        snow_raw = safe_get(weather_data, 'snow')
        snow = None
        if snow_raw:
            snow = {
                'one_hour': safe_get(snow_raw, '1h'),
                'three_hours': safe_get(snow_raw, '3h')
            }
        
        # Transform sys data
        sys_raw = safe_get(weather_data, 'sys', {})
        sys = {
            'type': safe_get(sys_raw, 'type'),
            'id': safe_get(sys_raw, 'id'),
            'country': safe_get(sys_raw, 'country'),
            'sunrise': safe_get(sys_raw, 'sunrise'),
            'sunset': safe_get(sys_raw, 'sunset')
        }
        
        # Create the final transformed record
        transformed = {
            'city': safe_get(weather_data, 'name', 'Unknown'),
            'country': safe_get(sys_raw, 'country'),
            'coordinates': coordinates,
            'weather': weather,
            'main': main,
            'visibility': safe_get(weather_data, 'visibility'),
            'wind': wind,
            'clouds': clouds,
            'rain': rain,
            'snow': snow,
            'dt': safe_get(weather_data, 'dt', 0),
            'sys': sys,
            'timezone': safe_get(weather_data, 'timezone'),
            'id': safe_get(weather_data, 'id', 0),
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'producer_id': 'weather-data-producer'
        }
        
        return transformed
    
    def publish_to_kafka(self, weather_records: List[Dict[str, Any]]) -> bool:
        """Publish weather records to Kafka topic (or save to file for testing)"""
        try:
            published_count = 0
            
            if self.producer is None:
                # Save to file for testing when Kafka is not available
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_file = f"weather_data_{timestamp}.json"
                
                logger.info(f"Kafka not available, saving {len(weather_records)} records to {output_file}")
                
                # Save as JSON for inspection
                with open(output_file, 'w') as f:
                    json.dump(weather_records, f, indent=2, default=str)
                
                # Also save as Avro for testing serialization
                avro_file = f"weather_data_{timestamp}.avro"
                try:
                    with open(avro_file, 'wb') as f:
                        fastavro.writer(f, self.schema, weather_records)
                    logger.info(f"Successfully saved Avro data to {avro_file}")
                except Exception as e:
                    logger.error(f"Failed to save Avro data: {e}")
                
                return True
            
            # Original Kafka publishing code (when producer is available)
            futures = []
            
            for record in weather_records:
                try:
                    # Create a unique key for each weather record
                    city = record.get('city', 'UNKNOWN')
                    timestamp = record.get('dt', 0)
                    key = f"{city}_{timestamp}"
                    
                    # Send message to Kafka (value_serializer handles Avro serialization)
                    future = self.producer.send(
                        self.config.kafka_topic,
                        key=key.encode('utf-8'),
                        value=record
                    )
                    futures.append(future)
                    published_count += 1
                    
                except Exception as e:
                    logger.error(f"Failed to publish weather record: {e}")
                    continue
            
            # Wait for all messages to be delivered
            for future in futures:
                try:
                    record_metadata = future.get(timeout=30)
                    logger.debug(f'Message delivered to {record_metadata.topic} [{record_metadata.partition}]')
                except Exception as e:
                    logger.error(f'Message delivery failed: {e}')
            
            logger.info(f"Successfully published {published_count} weather records to topic '{self.config.kafka_topic}'")
            return published_count > 0
            
        except Exception as e:
            logger.error(f"Failed to publish to Kafka: {e}")
            return False
    
    def fetch_and_publish(self) -> bool:
        """Fetch weather data and publish to Kafka"""
        logger.info("Starting weather data fetch and publish cycle")
        
        # Fetch weather data from API
        weather_data = self.fetch_weather_data()
        if not weather_data:
            logger.warning("No weather data retrieved, skipping publish")
            return False
        
        # Transform data to match Avro schema
        transformed_records = []
        for weather in weather_data:
            try:
                transformed = self.transform_weather_data(weather)
                transformed_records.append(transformed)
            except Exception as e:
                logger.error(f"Failed to transform weather record: {e}")
                continue
        
        if not transformed_records:
            logger.warning("No valid weather records after transformation")
            return False
        
        # Publish to Kafka
        success = self.publish_to_kafka(transformed_records)
        
        if success:
            logger.info(f"Successfully completed fetch and publish cycle with {len(transformed_records)} records")
        else:
            logger.error("Failed to complete fetch and publish cycle")
        
        return success
    
    def start_scheduled_producer(self):
        """Start the scheduled weather data producer"""
        logger.info(f"Starting scheduled weather data producer (interval: {self.config.fetch_interval_minutes} minutes)")
        
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
    parser = argparse.ArgumentParser(description='Weather Data Producer')
    parser.add_argument('--continuous', action='store_true', 
                       help='Run continuously with scheduled fetching')
    parser.add_argument('--interval', type=int, default=10,
                       help='Fetch interval in minutes (default: 10)')
    parser.add_argument('--api-key', type=str,
                       help='OpenWeatherMap API key (overrides env var)')
    parser.add_argument('--kafka-brokers', type=str,
                       help='Kafka brokers (overrides env var)')
    parser.add_argument('--kafka-topic', type=str,
                       help='Kafka topic (overrides env var)')
    parser.add_argument('--cities', type=str,
                       help='Comma-separated list of cities (overrides default)')
    
    args = parser.parse_args()
    
    # Load configuration
    config = WeatherConfig.from_env()
    
    # Override with command line arguments
    if args.api_key:
        config.api_key = args.api_key
    if args.kafka_brokers:
        config.kafka_brokers = args.kafka_brokers
    if args.kafka_topic:
        config.kafka_topic = args.kafka_topic
    if args.interval:
        config.fetch_interval_minutes = args.interval
    if args.cities:
        config.cities = [city.strip() for city in args.cities.split(',')]
    
    # Validate required configuration
    if not config.api_key:
        logger.error("OpenWeatherMap API key is required. Set OPENWEATHER_API_KEY environment variable or use --api-key")
        sys.exit(1)
    
    # Create and run producer
    producer = WeatherDataProducer(config)
    
    if args.continuous:
        producer.start_scheduled_producer()
    else:
        # Run once
        success = producer.fetch_and_publish()
        sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

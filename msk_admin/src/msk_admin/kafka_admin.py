"""Kafka Admin API operations with idempotent, retrying wrappers."""

import time
from typing import Dict, List, Optional, Any

import structlog
from confluent_kafka.admin import AdminClient, NewTopic, ConfigResource, ConfigEntry
from confluent_kafka import KafkaException
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from .config import Settings
from .topic_profiles import get_profile, merge_configs, validate_config
from .iam_oauth import get_iam_oauth_config

logger = structlog.get_logger()


class KafkaAdminError(Exception):
    """Custom exception for Kafka admin operations."""
    pass


class KafkaAdmin:
    """Kafka AdminClient wrapper with retry logic and validation."""
    
    def __init__(self, settings: Optional[Settings] = None):
        """Initialize Kafka admin client.
        
        Args:
            settings: Application settings. If None, will create new instance.
        """
        self.settings = settings or Settings()
        self._admin_client = None
        
    @property
    def admin_client(self) -> AdminClient:
        """Lazy initialization of AdminClient."""
        if self._admin_client is None:
            config = self.settings.get_kafka_config()
            
            # Add IAM OAuth configuration if needed
            if (self.settings.kafka_security_protocol.value == "SASL_SSL" and 
                self.settings.kafka_sasl_mechanism.value == "OAUTHBEARER"):
                oauth_config = get_iam_oauth_config(self.settings.aws_region)
                config.update(oauth_config)
            
            logger.info("Initializing Kafka AdminClient", config_keys=list(config.keys()))
            self._admin_client = AdminClient(config)
            
        return self._admin_client
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception_type((KafkaException, KafkaAdminError))
    )
    def create_topic(
        self,
        name: str,
        partitions: Optional[int] = None,
        replication_factor: Optional[int] = None,
        config: Optional[Dict[str, Any]] = None,
        profile: str = "general_throughput"
    ) -> None:
        """Create a Kafka topic with validation and retry logic.
        
        Args:
            name: Topic name
            partitions: Number of partitions (default from settings)
            replication_factor: Replication factor (default from settings)
            config: Topic configuration overrides
            profile: Topic configuration profile to use
            
        Raises:
            KafkaAdminError: If topic creation fails
        """
        start_time = time.time()
        
        # Use defaults from settings if not provided
        partitions = partitions or self.settings.default_partitions
        replication_factor = replication_factor or self.settings.default_replication_factor
        
        # Validate inputs
        if partitions < 1:
            raise KafkaAdminError(f"Partitions must be >= 1, got {partitions}")
        
        if replication_factor < 1:
            raise KafkaAdminError(f"Replication factor must be >= 1, got {replication_factor}")
        
        # Get profile configuration and merge with overrides
        profile_config = get_profile(profile)
        final_config = merge_configs(profile_config, config or {})
        
        # Validate final configuration
        validate_config(final_config, replication_factor)
        
        logger.info(
            "Creating topic",
            topic=name,
            partitions=partitions,
            replication_factor=replication_factor,
            profile=profile,
            config_count=len(final_config)
        )
        
        try:
            # Check if topic already exists
            existing_topics = self.list_topics()
            if name in existing_topics:
                logger.info("Topic already exists", topic=name)
                return
            
            # Create topic
            new_topic = NewTopic(
                topic=name,
                num_partitions=partitions,
                replication_factor=replication_factor,
                config=final_config
            )
            
            futures = self.admin_client.create_topics([new_topic])
            
            # Wait for creation to complete
            for topic, future in futures.items():
                try:
                    future.result(timeout=30)  # 30 second timeout
                    elapsed_ms = int((time.time() - start_time) * 1000)
                    logger.info(
                        "Topic created successfully",
                        topic=topic,
                        partitions=partitions,
                        replication_factor=replication_factor,
                        elapsed_ms=elapsed_ms
                    )
                except Exception as e:
                    error_msg = f"Failed to create topic '{topic}': {e}"
                    logger.error("Topic creation failed", topic=topic, error=str(e))
                    raise KafkaAdminError(error_msg)
                    
        except Exception as e:
            if "already exists" in str(e).lower():
                logger.info("Topic already exists", topic=name)
                return
            raise KafkaAdminError(f"Failed to create topic '{name}': {e}")
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=8),
        retry=retry_if_exception_type((KafkaException, KafkaAdminError))
    )
    def list_topics(self) -> List[str]:
        """List all Kafka topics.
        
        Returns:
            List of topic names
            
        Raises:
            KafkaAdminError: If listing topics fails
        """
        try:
            metadata = self.admin_client.list_topics(timeout=10)
            topics = list(metadata.topics.keys())
            
            # Filter out internal topics
            user_topics = [t for t in topics if not t.startswith('__')]
            
            logger.info("Listed topics", topic_count=len(user_topics))
            return sorted(user_topics)
            
        except Exception as e:
            error_msg = f"Failed to list topics: {e}"
            logger.error("Topic listing failed", error=str(e))
            raise KafkaAdminError(error_msg)
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=8),
        retry=retry_if_exception_type((KafkaException, KafkaAdminError))
    )
    def describe_topic(self, name: str) -> Dict[str, Any]:
        """Describe a Kafka topic.
        
        Args:
            name: Topic name
            
        Returns:
            Dictionary with topic metadata and configuration
            
        Raises:
            KafkaAdminError: If describing topic fails
        """
        try:
            # Get topic metadata
            metadata = self.admin_client.list_topics(topic=name, timeout=10)
            
            if name not in metadata.topics:
                raise KafkaAdminError(f"Topic '{name}' not found")
            
            topic_metadata = metadata.topics[name]
            
            # Get topic configuration
            config_resource = ConfigResource(ConfigResource.Type.TOPIC, name)
            configs = self.admin_client.describe_configs([config_resource])
            
            topic_config = {}
            for resource, future in configs.items():
                try:
                    config_result = future.result(timeout=10)
                    topic_config = {
                        entry.name: entry.value 
                        for entry in config_result.values()
                        if not entry.is_default  # Only non-default configs
                    }
                except Exception as e:
                    logger.warning("Failed to get topic config", topic=name, error=str(e))
            
            # Build response
            result = {
                "name": name,
                "partitions": len(topic_metadata.partitions),
                "replication_factor": len(topic_metadata.partitions[0].replicas) if topic_metadata.partitions else 0,
                "config": topic_config,
                "partition_details": []
            }
            
            # Add partition details
            for partition_id, partition in topic_metadata.partitions.items():
                partition_info = {
                    "id": partition_id,
                    "leader": partition.leader,
                    "replicas": partition.replicas,
                    "isr": partition.isrs,
                    "error": str(partition.error) if partition.error else None
                }
                result["partition_details"].append(partition_info)
            
            logger.info("Described topic", topic=name, partitions=result["partitions"])
            return result
            
        except KafkaAdminError:
            raise
        except Exception as e:
            error_msg = f"Failed to describe topic '{name}': {e}"
            logger.error("Topic description failed", topic=name, error=str(e))
            raise KafkaAdminError(error_msg)
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception_type((KafkaException, KafkaAdminError))
    )
    def alter_topic_config(self, name: str, config: Dict[str, Any]) -> None:
        """Alter topic configuration.
        
        Args:
            name: Topic name
            config: Configuration changes to apply
            
        Raises:
            KafkaAdminError: If altering config fails
        """
        start_time = time.time()
        
        logger.info("Altering topic config", topic=name, config_changes=config)
        
        try:
            # Verify topic exists
            if name not in self.list_topics():
                raise KafkaAdminError(f"Topic '{name}' not found")
            
            # Prepare config entries for incremental alter
            config_entries = []
            for key, value in config.items():
                config_entries.append(ConfigEntry(key, str(value)))
            
            config_resource = ConfigResource(ConfigResource.Type.TOPIC, name)
            configs = {config_resource: config_entries}
            
            # Use incremental alter if available (Kafka 2.3+)
            try:
                futures = self.admin_client.incremental_alter_configs(configs)
            except AttributeError:
                # Fall back to alter_configs for older Kafka versions
                futures = self.admin_client.alter_configs(configs)
            
            # Wait for completion
            for resource, future in futures.items():
                try:
                    future.result(timeout=30)
                    elapsed_ms = int((time.time() - start_time) * 1000)
                    logger.info(
                        "Topic config altered successfully",
                        topic=name,
                        elapsed_ms=elapsed_ms
                    )
                except Exception as e:
                    error_msg = f"Failed to alter config for topic '{name}': {e}"
                    logger.error("Config alteration failed", topic=name, error=str(e))
                    raise KafkaAdminError(error_msg)
                    
        except KafkaAdminError:
            raise
        except Exception as e:
            error_msg = f"Failed to alter topic config '{name}': {e}"
            logger.error("Topic config alteration failed", topic=name, error=str(e))
            raise KafkaAdminError(error_msg)
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception_type((KafkaException, KafkaAdminError))
    )
    def delete_topic(self, name: str) -> None:
        """Delete a Kafka topic.
        
        Args:
            name: Topic name
            
        Raises:
            KafkaAdminError: If topic deletion fails
        """
        start_time = time.time()
        
        logger.info("Deleting topic", topic=name)
        
        try:
            # Verify topic exists
            if name not in self.list_topics():
                logger.info("Topic does not exist", topic=name)
                return
            
            futures = self.admin_client.delete_topics([name])
            
            # Wait for deletion to complete
            for topic, future in futures.items():
                try:
                    future.result(timeout=30)
                    elapsed_ms = int((time.time() - start_time) * 1000)
                    logger.info(
                        "Topic deleted successfully",
                        topic=topic,
                        elapsed_ms=elapsed_ms
                    )
                except Exception as e:
                    error_msg = f"Failed to delete topic '{topic}': {e}"
                    logger.error("Topic deletion failed", topic=topic, error=str(e))
                    raise KafkaAdminError(error_msg)
                    
        except KafkaAdminError:
            raise
        except Exception as e:
            error_msg = f"Failed to delete topic '{name}': {e}"
            logger.error("Topic deletion failed", topic=name, error=str(e))
            raise KafkaAdminError(error_msg)
    
    def health_check(self) -> Dict[str, Any]:
        """Perform a health check on the Kafka cluster.
        
        Returns:
            Dictionary with health check results
        """
        try:
            start_time = time.time()
            
            # Try to list topics as a basic connectivity test
            topics = self.list_topics()
            
            # Get cluster metadata
            metadata = self.admin_client.list_topics(timeout=5)
            brokers = list(metadata.brokers.values())
            
            elapsed_ms = int((time.time() - start_time) * 1000)
            
            return {
                "status": "healthy",
                "broker_count": len(brokers),
                "topic_count": len(topics),
                "response_time_ms": elapsed_ms,
                "brokers": [{"id": b.id, "host": b.host, "port": b.port} for b in brokers]
            }
            
        except Exception as e:
            return {
                "status": "unhealthy",
                "error": str(e),
                "response_time_ms": int((time.time() - start_time) * 1000) if 'start_time' in locals() else None
            }

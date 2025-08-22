"""Configuration management with Pydantic settings and bootstrap resolution."""

import os
from enum import Enum
from typing import Optional

import boto3
import structlog
from pydantic import Field, validator
from pydantic_settings import BaseSettings

logger = structlog.get_logger()


class SecurityProtocol(str, Enum):
    """Kafka security protocols."""
    SSL = "SSL"
    SASL_SSL = "SASL_SSL"


class SaslMechanism(str, Enum):
    """SASL authentication mechanisms."""
    SCRAM_SHA_512 = "SCRAM-SHA-512"
    OAUTHBEARER = "OAUTHBEARER"
    NONE = ""


class Settings(BaseSettings):
    """Application settings with environment variable support."""
    
    # AWS Configuration
    aws_region: str = Field(default="us-east-1", env="AWS_REGION")
    msk_cluster_arn: Optional[str] = Field(default=None, env="MSK_CLUSTER_ARN")
    
    # Kafka Configuration
    kafka_bootstrap: Optional[str] = Field(default=None, env="KAFKA_BOOTSTRAP")
    kafka_security_protocol: SecurityProtocol = Field(
        default=SecurityProtocol.SASL_SSL, 
        env="KAFKA_SECURITY_PROTOCOL"
    )
    kafka_sasl_mechanism: SaslMechanism = Field(
        default=SaslMechanism.OAUTHBEARER, 
        env="KAFKA_SASL_MECHANISM"
    )
    
    # SCRAM Authentication
    kafka_sasl_username: Optional[str] = Field(default=None, env="KAFKA_SASL_USERNAME")
    kafka_sasl_password: Optional[str] = Field(default=None, env="KAFKA_SASL_PASSWORD")
    
    # SSL Configuration
    ssl_ca_location: Optional[str] = Field(default=None, env="SSL_CA_LOCATION")
    ssl_cert_location: Optional[str] = Field(default=None, env="SSL_CERT_LOCATION")
    ssl_key_location: Optional[str] = Field(default=None, env="SSL_KEY_LOCATION")
    
    # Schema Registry
    glue_registry_name: str = Field(default="weatherxflights", env="GLUE_REGISTRY_NAME")
    
    # Topic Defaults
    default_partitions: int = Field(default=6, env="DEFAULT_PARTITIONS")
    default_replication_factor: int = Field(default=3, env="DEFAULT_REPLICATION_FACTOR")
    default_min_insync_replicas: int = Field(default=2, env="DEFAULT_MIN_INSYNC_REPLICAS")
    
    # Logging
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False
    
    @validator("kafka_sasl_username")
    def validate_scram_credentials(cls, v, values):
        """Validate SCRAM credentials when SCRAM mechanism is used."""
        sasl_mechanism = values.get("kafka_sasl_mechanism")
        if sasl_mechanism == SaslMechanism.SCRAM_SHA_512:
            if not v or not values.get("kafka_sasl_password"):
                raise ValueError(
                    "KAFKA_SASL_USERNAME and KAFKA_SASL_PASSWORD are required "
                    "when using SCRAM-SHA-512"
                )
        return v
    
    @validator("default_min_insync_replicas")
    def validate_min_insync_replicas(cls, v, values):
        """Validate min.insync.replicas against replication factor."""
        replication_factor = values.get("default_replication_factor", 3)
        if v >= replication_factor:
            raise ValueError(
                f"min.insync.replicas ({v}) must be less than "
                f"replication.factor ({replication_factor})"
            )
        return v
    
    def get_bootstrap_servers(self) -> str:
        """Resolve bootstrap servers from MSK cluster ARN or use provided string."""
        if self.kafka_bootstrap:
            logger.info("Using provided bootstrap servers", servers=self.kafka_bootstrap)
            return self.kafka_bootstrap
        
        if not self.msk_cluster_arn:
            raise ValueError(
                "Either KAFKA_BOOTSTRAP or MSK_CLUSTER_ARN must be provided"
            )
        
        logger.info("Resolving bootstrap servers from MSK cluster", arn=self.msk_cluster_arn)
        
        try:
            kafka_client = boto3.client("kafka", region_name=self.aws_region)
            response = kafka_client.get_bootstrap_brokers(ClusterArn=self.msk_cluster_arn)
            
            # Select appropriate bootstrap string based on security protocol and SASL mechanism
            if self.kafka_security_protocol == SecurityProtocol.SSL:
                bootstrap_servers = response["BootstrapBrokerStringTls"]
            elif self.kafka_sasl_mechanism == SaslMechanism.SCRAM_SHA_512:
                bootstrap_servers = response["BootstrapBrokerStringSaslScram"]
            elif self.kafka_sasl_mechanism == SaslMechanism.OAUTHBEARER:
                bootstrap_servers = response["BootstrapBrokerStringSaslIam"]
            else:
                raise ValueError(f"Unsupported configuration: {self.kafka_security_protocol}/{self.kafka_sasl_mechanism}")
            
            logger.info("Resolved bootstrap servers", servers=bootstrap_servers)
            return bootstrap_servers
            
        except Exception as e:
            logger.error("Failed to resolve bootstrap servers", error=str(e), arn=self.msk_cluster_arn)
            raise ValueError(f"Failed to resolve bootstrap servers: {e}")
    
    def get_kafka_config(self) -> dict:
        """Generate Kafka client configuration dictionary."""
        config = {
            "bootstrap.servers": self.get_bootstrap_servers(),
            "security.protocol": self.kafka_security_protocol.value,
        }
        
        # Add SASL configuration
        if self.kafka_security_protocol == SecurityProtocol.SASL_SSL:
            config["sasl.mechanism"] = self.kafka_sasl_mechanism.value
            
            if self.kafka_sasl_mechanism == SaslMechanism.SCRAM_SHA_512:
                config["sasl.username"] = self.kafka_sasl_username
                config["sasl.password"] = self.kafka_sasl_password
            elif self.kafka_sasl_mechanism == SaslMechanism.OAUTHBEARER:
                # IAM OAUTH configuration will be handled by iam_oauth.py
                pass
        
        # Add SSL configuration
        if self.ssl_ca_location:
            config["ssl.ca.location"] = self.ssl_ca_location
        if self.ssl_cert_location:
            config["ssl.certificate.location"] = self.ssl_cert_location
        if self.ssl_key_location:
            config["ssl.key.location"] = self.ssl_key_location
        
        return config


def get_settings() -> Settings:
    """Get application settings instance."""
    return Settings()

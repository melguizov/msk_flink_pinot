"""Bootstrap utilities for MSK cluster discovery and configuration."""

import boto3
import structlog
from typing import Dict, Optional
from botocore.exceptions import ClientError, BotoCoreError

logger = structlog.get_logger()


class BootstrapError(Exception):
    """Exception raised when bootstrap resolution fails."""
    pass


def resolve_bootstrap_servers(
    cluster_arn: str,
    region: str,
    security_protocol: str = "SASL_SSL",
    sasl_mechanism: str = "OAUTHBEARER"
) -> str:
    """Resolve bootstrap servers from MSK cluster ARN.
    
    Args:
        cluster_arn: MSK cluster ARN
        region: AWS region
        security_protocol: Kafka security protocol (SSL, SASL_SSL)
        sasl_mechanism: SASL mechanism (SCRAM-SHA-512, OAUTHBEARER)
        
    Returns:
        Bootstrap servers string
        
    Raises:
        BootstrapError: If resolution fails
    """
    logger.info("Resolving bootstrap servers", cluster_arn=cluster_arn, region=region)
    
    try:
        kafka_client = boto3.client("kafka", region_name=region)
        response = kafka_client.get_bootstrap_brokers(ClusterArn=cluster_arn)
        
        # Select appropriate bootstrap string based on configuration
        if security_protocol == "SSL":
            bootstrap_servers = response.get("BootstrapBrokerStringTls")
        elif security_protocol == "SASL_SSL":
            if sasl_mechanism == "SCRAM-SHA-512":
                bootstrap_servers = response.get("BootstrapBrokerStringSaslScram")
            elif sasl_mechanism == "OAUTHBEARER":
                bootstrap_servers = response.get("BootstrapBrokerStringSaslIam")
            else:
                raise BootstrapError(f"Unsupported SASL mechanism: {sasl_mechanism}")
        else:
            raise BootstrapError(f"Unsupported security protocol: {security_protocol}")
        
        if not bootstrap_servers:
            raise BootstrapError(
                f"No bootstrap servers found for configuration: "
                f"{security_protocol}/{sasl_mechanism}"
            )
        
        logger.info("Bootstrap servers resolved", servers=bootstrap_servers)
        return bootstrap_servers
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_msg = e.response['Error']['Message']
        
        if error_code == 'NotFoundException':
            raise BootstrapError(f"MSK cluster not found: {cluster_arn}")
        elif error_code == 'UnauthorizedOperation':
            raise BootstrapError(f"Access denied to MSK cluster: {cluster_arn}")
        else:
            raise BootstrapError(f"AWS API error: {error_msg}")
            
    except BotoCoreError as e:
        raise BootstrapError(f"AWS connection error: {e}")
    except Exception as e:
        raise BootstrapError(f"Unexpected error resolving bootstrap servers: {e}")


def get_cluster_info(cluster_arn: str, region: str) -> Dict[str, any]:
    """Get detailed information about an MSK cluster.
    
    Args:
        cluster_arn: MSK cluster ARN
        region: AWS region
        
    Returns:
        Dictionary with cluster information
        
    Raises:
        BootstrapError: If getting cluster info fails
    """
    logger.info("Getting cluster info", cluster_arn=cluster_arn)
    
    try:
        kafka_client = boto3.client("kafka", region_name=region)
        
        # Get cluster description
        response = kafka_client.describe_cluster(ClusterArn=cluster_arn)
        cluster_info = response['ClusterInfo']
        
        # Get bootstrap brokers
        brokers_response = kafka_client.get_bootstrap_brokers(ClusterArn=cluster_arn)
        
        result = {
            'cluster_name': cluster_info['ClusterName'],
            'cluster_arn': cluster_info['ClusterArn'],
            'state': cluster_info['State'],
            'kafka_version': cluster_info['CurrentBrokerSoftwareInfo']['KafkaVersion'],
            'number_of_broker_nodes': cluster_info['NumberOfBrokerNodes'],
            'instance_type': cluster_info['BrokerNodeGroupInfo']['InstanceType'],
            'storage_info': cluster_info['BrokerNodeGroupInfo']['StorageInfo'],
            'encryption_info': cluster_info.get('EncryptionInfo', {}),
            'authentication_info': cluster_info.get('ClientAuthentication', {}),
            'bootstrap_brokers': {
                'tls': brokers_response.get('BootstrapBrokerStringTls'),
                'sasl_scram': brokers_response.get('BootstrapBrokerStringSaslScram'),
                'sasl_iam': brokers_response.get('BootstrapBrokerStringSaslIam'),
                'public_tls': brokers_response.get('BootstrapBrokerStringPublicTls'),
                'public_sasl_scram': brokers_response.get('BootstrapBrokerStringPublicSaslScram'),
                'public_sasl_iam': brokers_response.get('BootstrapBrokerStringPublicSaslIam')
            }
        }
        
        logger.info("Cluster info retrieved", cluster_name=result['cluster_name'])
        return result
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_msg = e.response['Error']['Message']
        raise BootstrapError(f"Failed to get cluster info: {error_msg}")
    except Exception as e:
        raise BootstrapError(f"Unexpected error getting cluster info: {e}")


def list_clusters(region: str) -> list:
    """List all MSK clusters in a region.
    
    Args:
        region: AWS region
        
    Returns:
        List of cluster information dictionaries
        
    Raises:
        BootstrapError: If listing clusters fails
    """
    logger.info("Listing MSK clusters", region=region)
    
    try:
        kafka_client = boto3.client("kafka", region_name=region)
        clusters = []
        
        paginator = kafka_client.get_paginator('list_clusters')
        for page in paginator.paginate():
            for cluster in page['ClusterInfoList']:
                cluster_info = {
                    'cluster_name': cluster['ClusterName'],
                    'cluster_arn': cluster['ClusterArn'],
                    'state': cluster['State'],
                    'kafka_version': cluster['CurrentBrokerSoftwareInfo']['KafkaVersion'],
                    'creation_time': cluster['CreationTime']
                }
                clusters.append(cluster_info)
        
        logger.info("Clusters listed", count=len(clusters))
        return clusters
        
    except ClientError as e:
        error_msg = e.response['Error']['Message']
        raise BootstrapError(f"Failed to list clusters: {error_msg}")
    except Exception as e:
        raise BootstrapError(f"Unexpected error listing clusters: {e}")


def validate_cluster_access(cluster_arn: str, region: str) -> bool:
    """Validate access to an MSK cluster.
    
    Args:
        cluster_arn: MSK cluster ARN
        region: AWS region
        
    Returns:
        True if access is valid, False otherwise
    """
    try:
        cluster_info = get_cluster_info(cluster_arn, region)
        return cluster_info['state'] in ['ACTIVE', 'UPDATING']
    except BootstrapError:
        return False

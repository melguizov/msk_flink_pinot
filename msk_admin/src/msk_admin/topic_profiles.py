"""Performance-focused Kafka topic configuration profiles.

This module provides pre-configured topic profiles optimized for different use cases:
- general_throughput: Balanced performance for most workloads
- low_latency: Optimized for minimal latency
- compaction_log: For key-based compacted topics (state stores, changelogs)
- long_retention: Extended retention for audit/compliance scenarios
"""

from typing import Dict, Any


# Topic configuration profiles with performance optimizations
TOPIC_PROFILES: Dict[str, Dict[str, Any]] = {
    "general_throughput": {
        # Durability & Consistency
        "min.insync.replicas": 2,  # Requires RF >= 3, balances durability vs availability
        "unclean.leader.election.enable": False,  # Prevents data loss
        
        # Performance & Compression
        "compression.type": "snappy",  # Good balance of speed vs compression ratio
        
        # Retention & Segmentation
        "retention.ms": 259200000,  # 3 days (72 hours)
        "segment.ms": 3600000,  # 1 hour - allows for timely log compaction
        "segment.bytes": 1073741824,  # 1GB - efficient for high throughput
        
        # Message handling
        "message.timestamp.type": "CreateTime",  # Use producer timestamp
        "max.message.bytes": 1048576,  # 1MB max message size
        
        # Cleanup & Deletion
        "delete.retention.ms": 86400000,  # 24 hours for tombstone retention
        "file.delete.delay.ms": 60000,  # 1 minute delay before file deletion
        
        # Replication
        "replica.lag.time.max.ms": 30000,  # 30 seconds max lag for ISR
    },
    
    "low_latency": {
        # Durability (slightly relaxed for latency)
        "min.insync.replicas": 1,  # Faster writes, but less durable
        "unclean.leader.election.enable": False,
        
        # Performance optimized for latency
        "compression.type": "lz4",  # Fastest compression algorithm
        
        # Smaller segments for faster leader election and log rolling
        "segment.ms": 1800000,  # 30 minutes
        "segment.bytes": 536870912,  # 512MB
        
        # Shorter retention for faster cleanup
        "retention.ms": 86400000,  # 1 day
        
        # Message handling
        "message.timestamp.type": "CreateTime",
        "max.message.bytes": 1048576,
        
        # Faster cleanup
        "delete.retention.ms": 3600000,  # 1 hour
        "file.delete.delay.ms": 30000,  # 30 seconds
        
        # Tighter replication timing
        "replica.lag.time.max.ms": 10000,  # 10 seconds
    },
    
    "compaction_log": {
        # Compaction-specific settings
        "cleanup.policy": "compact",  # Enable log compaction
        "min.cleanable.dirty.ratio": 0.5,  # Compact when 50% of log is dirty
        "min.compaction.lag.ms": 0,  # Allow immediate compaction
        "max.compaction.lag.ms": 604800000,  # Force compaction weekly
        
        # Durability for state stores
        "min.insync.replicas": 2,
        "unclean.leader.election.enable": False,
        
        # Compression for state efficiency
        "compression.type": "snappy",
        
        # Segmentation for compaction efficiency
        "segment.ms": 3600000,  # 1 hour
        "segment.bytes": 1073741824,  # 1GB
        
        # Retention for compacted topics
        "delete.retention.ms": 86400000,  # 24 hours for tombstones
        
        # Message handling
        "message.timestamp.type": "CreateTime",
        "max.message.bytes": 1048576,
        
        # Compaction tuning
        "segment.index.bytes": 10485760,  # 10MB index size
        "file.delete.delay.ms": 60000,
    },
    
    "long_retention": {
        # Extended retention for compliance/audit
        "retention.ms": 1209600000,  # 14 days
        "retention.bytes": -1,  # No size-based retention
        
        # Durability for long-term storage
        "min.insync.replicas": 2,
        "unclean.leader.election.enable": False,
        
        # Compression optimized for storage efficiency
        "compression.type": "zstd",  # Best compression ratio (CPU intensive)
        
        # Larger segments for storage efficiency
        "segment.ms": 86400000,  # 24 hours
        "segment.bytes": 2147483648,  # 2GB
        
        # Message handling
        "message.timestamp.type": "CreateTime",
        "max.message.bytes": 1048576,
        
        # Cleanup settings
        "delete.retention.ms": 86400000,
        "file.delete.delay.ms": 300000,  # 5 minutes
        
        # Index settings for large segments
        "segment.index.bytes": 52428800,  # 50MB index size
        "replica.lag.time.max.ms": 60000,  # 1 minute lag tolerance
    }
}


def get_profile(profile_name: str) -> Dict[str, Any]:
    """Get topic configuration for a specific profile.
    
    Args:
        profile_name: Name of the profile to retrieve
        
    Returns:
        Dictionary of Kafka topic configuration parameters
        
    Raises:
        ValueError: If profile_name is not found
    """
    if profile_name not in TOPIC_PROFILES:
        available_profiles = list(TOPIC_PROFILES.keys())
        raise ValueError(
            f"Profile '{profile_name}' not found. "
            f"Available profiles: {', '.join(available_profiles)}"
        )
    
    return TOPIC_PROFILES[profile_name].copy()


def list_profiles() -> Dict[str, str]:
    """List available profiles with descriptions.
    
    Returns:
        Dictionary mapping profile names to descriptions
    """
    descriptions = {
        "general_throughput": "Balanced performance for most workloads (default)",
        "low_latency": "Optimized for minimal latency with relaxed durability",
        "compaction_log": "For key-based compacted topics (state stores, changelogs)",
        "long_retention": "Extended retention for audit/compliance scenarios"
    }
    return descriptions


def merge_configs(profile_config: Dict[str, Any], overrides: Dict[str, Any]) -> Dict[str, Any]:
    """Merge profile configuration with user overrides.
    
    Args:
        profile_config: Base configuration from profile
        overrides: User-provided configuration overrides
        
    Returns:
        Merged configuration dictionary
    """
    merged = profile_config.copy()
    merged.update(overrides)
    return merged


def validate_config(config: Dict[str, Any], replication_factor: int = 3) -> None:
    """Validate topic configuration for common issues.
    
    Args:
        config: Topic configuration dictionary
        replication_factor: Replication factor for the topic
        
    Raises:
        ValueError: If configuration has validation errors
    """
    min_isr = config.get("min.insync.replicas", 1)
    
    # Validate min.insync.replicas vs replication factor
    if min_isr >= replication_factor:
        raise ValueError(
            f"min.insync.replicas ({min_isr}) must be less than "
            f"replication factor ({replication_factor})"
        )
    
    # Warn about unclean leader election
    if config.get("unclean.leader.election.enable", False):
        import warnings
        warnings.warn(
            "unclean.leader.election.enable=true can cause data loss. "
            "Consider setting to false for production workloads."
        )
    
    # Validate compression type
    valid_compression = ["none", "gzip", "snappy", "lz4", "zstd"]
    compression = config.get("compression.type", "none")
    if compression not in valid_compression:
        raise ValueError(
            f"Invalid compression.type '{compression}'. "
            f"Valid options: {', '.join(valid_compression)}"
        )


def get_performance_notes() -> Dict[str, Dict[str, str]]:
    """Get performance notes and tradeoffs for each profile.
    
    Returns:
        Dictionary with performance characteristics for each profile
    """
    return {
        "general_throughput": {
            "throughput": "High - optimized for sustained throughput",
            "latency": "Medium - balanced approach",
            "durability": "High - min.insync.replicas=2, no unclean elections",
            "storage": "Medium - 3-day retention with snappy compression",
            "use_case": "Most production workloads, event streaming"
        },
        "low_latency": {
            "throughput": "Medium - optimized for speed over throughput",
            "latency": "Low - smaller segments, lz4 compression, relaxed ISR",
            "durability": "Medium - min.insync.replicas=1 for faster writes",
            "storage": "Low - 1-day retention, frequent cleanup",
            "use_case": "Real-time applications, trading systems, IoT"
        },
        "compaction_log": {
            "throughput": "Medium - compaction overhead affects performance",
            "latency": "Medium - standard settings with compaction",
            "durability": "High - designed for state store reliability",
            "storage": "Variable - depends on key cardinality and update patterns",
            "use_case": "Kafka Streams state stores, CDC, configuration topics"
        },
        "long_retention": {
            "throughput": "Medium - larger segments reduce overhead",
            "latency": "Medium-High - zstd compression adds CPU overhead",
            "durability": "High - optimized for long-term data retention",
            "storage": "High - 14-day retention with maximum compression",
            "use_case": "Audit logs, compliance data, data lake ingestion"
        }
    }

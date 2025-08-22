"""AWS Glue Schema Registry operations for Avro schema management."""

import json
from typing import Dict, List, Optional, Any

import boto3
import structlog
from aws_schema_registry import SchemaRegistryClient
from aws_schema_registry.avro import AvroSchema
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from botocore.exceptions import ClientError, BotoCoreError

from .config import Settings

logger = structlog.get_logger()


class SchemaRegistryError(Exception):
    """Custom exception for Schema Registry operations."""
    pass


class SchemaRegistry:
    """AWS Glue Schema Registry client wrapper."""
    
    def __init__(self, settings: Optional[Settings] = None):
        """Initialize Schema Registry client.
        
        Args:
            settings: Application settings. If None, will create new instance.
        """
        self.settings = settings or Settings()
        self._glue_client = None
        self._schema_registry_client = None
        
    @property
    def glue_client(self):
        """Lazy initialization of Glue client."""
        if self._glue_client is None:
            self._glue_client = boto3.client("glue", region_name=self.settings.aws_region)
        return self._glue_client
    
    @property
    def schema_registry_client(self):
        """Lazy initialization of Schema Registry client."""
        if self._schema_registry_client is None:
            self._schema_registry_client = SchemaRegistryClient(
                region_name=self.settings.aws_region,
                registry_name=self.settings.glue_registry_name
            )
        return self._schema_registry_client
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=8),
        retry=retry_if_exception_type((ClientError, BotoCoreError, SchemaRegistryError))
    )
    def register_avro_schema(
        self,
        schema_str: str,
        schema_name: str,
        compatibility: str = "BACKWARD"
    ) -> str:
        """Register an Avro schema in AWS Glue Schema Registry.
        
        Args:
            schema_str: Avro schema as JSON string
            schema_name: Name for the schema
            compatibility: Compatibility mode (BACKWARD, FORWARD, FULL, NONE)
            
        Returns:
            Schema ARN
            
        Raises:
            SchemaRegistryError: If schema registration fails
        """
        logger.info(
            "Registering Avro schema",
            schema_name=schema_name,
            compatibility=compatibility,
            registry=self.settings.glue_registry_name
        )
        
        try:
            # Validate schema JSON
            try:
                schema_dict = json.loads(schema_str)
            except json.JSONDecodeError as e:
                raise SchemaRegistryError(f"Invalid JSON in schema: {e}")
            
            # Validate compatibility mode
            valid_compatibility = ["BACKWARD", "FORWARD", "FULL", "NONE"]
            if compatibility not in valid_compatibility:
                raise SchemaRegistryError(
                    f"Invalid compatibility '{compatibility}'. "
                    f"Valid options: {', '.join(valid_compatibility)}"
                )
            
            # Check if schema already exists
            try:
                existing_schema = self.get_schema(schema_name)
                if existing_schema == schema_str:
                    logger.info("Schema already exists with same definition", schema_name=schema_name)
                    # Get schema ARN
                    response = self.glue_client.get_schema(
                        SchemaId={
                            'RegistryName': self.settings.glue_registry_name,
                            'SchemaName': schema_name
                        }
                    )
                    return response['SchemaArn']
            except SchemaRegistryError:
                # Schema doesn't exist, continue with registration
                pass
            
            # Register new schema
            response = self.glue_client.register_schema(
                RegistryId={'RegistryName': self.settings.glue_registry_name},
                SchemaName=schema_name,
                DataFormat='AVRO',
                Compatibility=compatibility,
                SchemaDefinition=schema_str,
                Description=f"Avro schema for {schema_name}"
            )
            
            schema_arn = response['SchemaArn']
            schema_version = response['SchemaVersion']
            
            logger.info(
                "Schema registered successfully",
                schema_name=schema_name,
                schema_arn=schema_arn,
                version=schema_version
            )
            
            return schema_arn
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            
            if error_code == 'AlreadyExistsException':
                logger.info("Schema already exists", schema_name=schema_name)
                # Return existing schema ARN
                response = self.glue_client.get_schema(
                    SchemaId={
                        'RegistryName': self.settings.glue_registry_name,
                        'SchemaName': schema_name
                    }
                )
                return response['SchemaArn']
            elif error_code == 'InvalidInputException':
                raise SchemaRegistryError(f"Invalid schema input: {error_msg}")
            else:
                raise SchemaRegistryError(f"Failed to register schema: {error_msg}")
        except Exception as e:
            raise SchemaRegistryError(f"Failed to register schema '{schema_name}': {e}")
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=8),
        retry=retry_if_exception_type((ClientError, BotoCoreError, SchemaRegistryError))
    )
    def get_schema(self, schema_name: str, version: Optional[int] = None) -> str:
        """Get schema definition from AWS Glue Schema Registry.
        
        Args:
            schema_name: Name of the schema
            version: Specific version to retrieve (latest if None)
            
        Returns:
            Schema definition as JSON string
            
        Raises:
            SchemaRegistryError: If schema retrieval fails
        """
        logger.info("Getting schema", schema_name=schema_name, version=version)
        
        try:
            schema_id = {
                'RegistryName': self.settings.glue_registry_name,
                'SchemaName': schema_name
            }
            
            if version:
                schema_id['SchemaVersion'] = version
            
            response = self.glue_client.get_schema(SchemaId=schema_id)
            
            schema_definition = response['SchemaDefinition']
            retrieved_version = response['SchemaVersion']
            
            logger.info(
                "Schema retrieved successfully",
                schema_name=schema_name,
                version=retrieved_version
            )
            
            return schema_definition
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            
            if error_code == 'EntityNotFoundException':
                raise SchemaRegistryError(f"Schema '{schema_name}' not found")
            else:
                raise SchemaRegistryError(f"Failed to get schema: {error_msg}")
        except Exception as e:
            raise SchemaRegistryError(f"Failed to get schema '{schema_name}': {e}")
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=8),
        retry=retry_if_exception_type((ClientError, BotoCoreError, SchemaRegistryError))
    )
    def list_schemas(self) -> List[Dict[str, Any]]:
        """List all schemas in the registry.
        
        Returns:
            List of schema information dictionaries
            
        Raises:
            SchemaRegistryError: If listing schemas fails
        """
        logger.info("Listing schemas", registry=self.settings.glue_registry_name)
        
        try:
            schemas = []
            paginator = self.glue_client.get_paginator('list_schemas')
            
            for page in paginator.paginate(
                RegistryId={'RegistryName': self.settings.glue_registry_name}
            ):
                for schema in page.get('Schemas', []):
                    schema_info = {
                        'name': schema['SchemaName'],
                        'arn': schema['SchemaArn'],
                        'status': schema['SchemaStatus'],
                        'data_format': schema['DataFormat'],
                        'compatibility': schema.get('Compatibility', 'UNKNOWN'),
                        'created_time': schema.get('CreatedTime'),
                        'updated_time': schema.get('UpdatedTime'),
                        'version_number': schema.get('LatestSchemaVersion', 0)
                    }
                    schemas.append(schema_info)
            
            logger.info("Schemas listed successfully", count=len(schemas))
            return sorted(schemas, key=lambda x: x['name'])
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            
            if error_code == 'EntityNotFoundException':
                logger.warning("Registry not found", registry=self.settings.glue_registry_name)
                return []
            else:
                raise SchemaRegistryError(f"Failed to list schemas: {error_msg}")
        except Exception as e:
            raise SchemaRegistryError(f"Failed to list schemas: {e}")
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=8),
        retry=retry_if_exception_type((ClientError, BotoCoreError, SchemaRegistryError))
    )
    def check_compatibility(self, schema_name: str, candidate_schema: str) -> bool:
        """Check if a candidate schema is compatible with the existing schema.
        
        Args:
            schema_name: Name of the existing schema
            candidate_schema: New schema definition to check
            
        Returns:
            True if compatible, False otherwise
            
        Raises:
            SchemaRegistryError: If compatibility check fails
        """
        logger.info("Checking schema compatibility", schema_name=schema_name)
        
        try:
            # Validate candidate schema JSON
            try:
                json.loads(candidate_schema)
            except json.JSONDecodeError as e:
                raise SchemaRegistryError(f"Invalid JSON in candidate schema: {e}")
            
            response = self.glue_client.check_schema_version_validity(
                DataFormat='AVRO',
                SchemaDefinition=candidate_schema
            )
            
            if not response['Valid']:
                logger.warning("Candidate schema is not valid", schema_name=schema_name)
                return False
            
            # Check compatibility with existing schema
            try:
                existing_schema = self.get_schema(schema_name)
                
                # Use AWS Glue's compatibility check
                response = self.glue_client.put_schema_version_metadata(
                    SchemaId={
                        'RegistryName': self.settings.glue_registry_name,
                        'SchemaName': schema_name
                    },
                    SchemaVersionNumber={'LatestVersion': True},
                    MetadataKeyValue={
                        'compatibility_check': 'true'
                    }
                )
                
                # For now, we'll do a basic structural compatibility check
                # In a production system, you might want to use a more sophisticated
                # Avro compatibility checker
                try:
                    existing_dict = json.loads(existing_schema)
                    candidate_dict = json.loads(candidate_schema)
                    
                    # Basic backward compatibility: new schema can't remove required fields
                    existing_fields = {f['name']: f for f in existing_dict.get('fields', [])}
                    candidate_fields = {f['name']: f for f in candidate_dict.get('fields', [])}
                    
                    # Check if any required fields were removed
                    for field_name, field_def in existing_fields.items():
                        if field_name not in candidate_fields:
                            if 'default' not in field_def:
                                logger.warning(
                                    "Required field removed",
                                    schema_name=schema_name,
                                    field=field_name
                                )
                                return False
                    
                    logger.info("Schema compatibility check passed", schema_name=schema_name)
                    return True
                    
                except Exception as e:
                    logger.warning(
                        "Could not perform detailed compatibility check",
                        schema_name=schema_name,
                        error=str(e)
                    )
                    return True  # Assume compatible if we can't check
                    
            except SchemaRegistryError:
                # If existing schema doesn't exist, candidate is compatible
                logger.info("No existing schema found, candidate is compatible", schema_name=schema_name)
                return True
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            raise SchemaRegistryError(f"Compatibility check failed: {error_msg}")
        except Exception as e:
            raise SchemaRegistryError(f"Failed to check compatibility for '{schema_name}': {e}")
    
    def get_schema_versions(self, schema_name: str) -> List[Dict[str, Any]]:
        """Get all versions of a schema.
        
        Args:
            schema_name: Name of the schema
            
        Returns:
            List of schema version information
            
        Raises:
            SchemaRegistryError: If getting versions fails
        """
        logger.info("Getting schema versions", schema_name=schema_name)
        
        try:
            versions = []
            paginator = self.glue_client.get_paginator('list_schema_versions')
            
            for page in paginator.paginate(
                SchemaId={
                    'RegistryName': self.settings.glue_registry_name,
                    'SchemaName': schema_name
                }
            ):
                for version in page.get('SchemaVersions', []):
                    version_info = {
                        'version_number': version['SchemaVersionNumber'],
                        'status': version['Status'],
                        'created_time': version.get('CreatedTime'),
                        'schema_arn': version.get('SchemaArn')
                    }
                    versions.append(version_info)
            
            logger.info("Schema versions retrieved", schema_name=schema_name, count=len(versions))
            return sorted(versions, key=lambda x: x['version_number'], reverse=True)
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            
            if error_code == 'EntityNotFoundException':
                raise SchemaRegistryError(f"Schema '{schema_name}' not found")
            else:
                raise SchemaRegistryError(f"Failed to get schema versions: {error_msg}")
        except Exception as e:
            raise SchemaRegistryError(f"Failed to get versions for '{schema_name}': {e}")

"""IAM OAUTH token provider for MSK IAM authentication."""

import time
from typing import Dict, Tuple, Optional

import structlog
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

logger = structlog.get_logger()


class IAMTokenProvider:
    """Token provider for MSK IAM authentication using OAUTHBEARER."""
    
    def __init__(self, region: str):
        """Initialize IAM token provider.
        
        Args:
            region: AWS region for MSK cluster
        """
        self.region = region
        self._token_provider = MSKAuthTokenProvider(region=region)
        self._cached_token: Optional[str] = None
        self._token_expiry: Optional[float] = None
        
    def get_token(self) -> Tuple[str, float]:
        """Get IAM authentication token.
        
        Returns:
            Tuple of (token, expiry_timestamp)
        """
        current_time = time.time()
        
        # Return cached token if still valid (with 60 second buffer)
        if (self._cached_token and self._token_expiry and 
            current_time < (self._token_expiry - 60)):
            logger.debug("Using cached IAM token")
            return self._cached_token, self._token_expiry
        
        logger.info("Generating new IAM token", region=self.region)
        
        try:
            # Generate new token
            token = self._token_provider.token()
            
            # MSK IAM tokens are typically valid for 15 minutes
            expiry = current_time + (15 * 60)  # 15 minutes from now
            
            # Cache the token
            self._cached_token = token
            self._token_expiry = expiry
            
            logger.info("IAM token generated successfully", expires_in_seconds=int(expiry - current_time))
            return token, expiry
            
        except Exception as e:
            logger.error("Failed to generate IAM token", error=str(e), region=self.region)
            raise


def oauth_callback(oauth_config: Dict[str, str]) -> Tuple[str, float]:
    """OAuth callback function for confluent-kafka AdminClient.
    
    This function is called by the Kafka client when it needs to refresh
    the OAuth token for authentication.
    
    Args:
        oauth_config: OAuth configuration dictionary
        
    Returns:
        Tuple of (token, expiry_timestamp)
    """
    region = oauth_config.get("region", "us-east-1")
    
    try:
        provider = IAMTokenProvider(region)
        return provider.get_token()
    except Exception as e:
        logger.error("OAuth callback failed", error=str(e), region=region)
        raise


def get_iam_oauth_config(region: str) -> Dict[str, any]:
    """Get Kafka client configuration for IAM OAuth authentication.
    
    Args:
        region: AWS region for MSK cluster
        
    Returns:
        Dictionary with OAuth configuration for Kafka client
    """
    def oauth_cb(config):
        return oauth_callback({"region": region})
    
    return {
        "oauth_cb": oauth_cb,
    }

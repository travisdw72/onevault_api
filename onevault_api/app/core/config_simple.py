"""
Simplified configuration for Render deployment without Node.js dependencies
"""
import os
from typing import Dict, Any, List, Optional
from pydantic_settings import BaseSettings
from pydantic import Field
from functools import lru_cache

class Settings(BaseSettings):
    """Application settings from environment variables."""
    
    # Database Configuration
    SYSTEM_DATABASE_URL: str = Field(default="", env="SYSTEM_DATABASE_URL")
    
    # Application Configuration
    APP_NAME: str = Field(default="OneVault Platform", env="APP_NAME")
    APP_VERSION: str = Field(default="1.0.0", env="APP_VERSION")
    DEBUG: bool = Field(default=False, env="DEBUG")
    LOG_LEVEL: str = Field(default="INFO", env="LOG_LEVEL")
    
    # CORS Configuration
    CORS_ORIGINS: List[str] = Field(default=["*"], env="CORS_ORIGINS")
    
    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'

@lru_cache()
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()

class SimpleCustomerConfigManager:
    """Simplified customer config manager for Render deployment."""
    
    def __init__(self):
        # Hardcoded config for one_spa customer
        self.customer_configs = {
            "one_spa": {
                "customer": {
                    "name": "The One Spa Oregon",
                    "industry": "Health & Wellness",
                    "type": "Spa & Wellness Center"
                },
                "branding": {
                    "primaryColor": "#2E8B57",
                    "secondaryColor": "#F0F8FF",
                    "logoUrl": "https://example.com/logo.png"
                },
                "locations": [
                    {
                        "name": "Main Location",
                        "address": "123 Wellness Way, Oregon",
                        "phone": "(555) 123-4567"
                    }
                ],
                "compliance": {
                    "hipaa": True,
                    "gdpr": False
                }
            }
        }
    
    def get_customer_config(self, customer_id: str) -> Optional[Dict[str, Any]]:
        """Get customer configuration."""
        return self.customer_configs.get(customer_id)
    
    def is_valid_customer(self, customer_id: str) -> bool:
        """Check if customer is valid."""
        return customer_id in self.customer_configs
    
    def get_all_customer_ids(self) -> List[str]:
        """Get all customer IDs."""
        return list(self.customer_configs.keys())

# Global instances
settings = get_settings()
customer_config_manager = SimpleCustomerConfigManager() 
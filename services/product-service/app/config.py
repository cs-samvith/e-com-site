from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application configuration"""

    # Service
    SERVICE_NAME: str = "product-service"
    SERVICE_PORT: int = 8081

    # Database
    DB_HOST: str = "postgres-service"
    DB_PORT: int = 5432
    DB_NAME: str = "products_db"
    DB_USER: str = "postgres"
    DB_PASSWORD: str = "postgres"

    # Redis
    REDIS_HOST: str = "redis-service"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: Optional[str] = None
    CACHE_TTL: int = 300  # 5 minutes

    # RabbitMQ
    RABBITMQ_HOST: str = "rabbitmq-service"
    RABBITMQ_PORT: int = 5672
    RABBITMQ_USER: str = "guest"
    RABBITMQ_PASSWORD: str = "guest"
    RABBITMQ_QUEUE: str = "inventory.updates"

    # Observability
    JAEGER_HOST: str = "jaeger-service"
    JAEGER_PORT: int = 6831

    # Mock Mode (for testing without dependencies)
    MOCK_MODE: bool = False

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

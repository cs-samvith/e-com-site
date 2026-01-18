from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application configuration"""

    # Service
    SERVICE_NAME: str = "user-service"
    SERVICE_PORT: int = 8080

    # Database
    DB_HOST: str = "postgres-service"
    DB_PORT: int = 5432
    DB_NAME: str = "users_db"
    DB_USER: str = "postgres"
    DB_PASSWORD: str = "postgres"

    # Redis (Sessions & Tokens)
    REDIS_HOST: str = "redis-service"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: Optional[str] = None
    SESSION_TTL: int = 86400  # 24 hours

    # RabbitMQ
    RABBITMQ_HOST: str = "rabbitmq-service"
    RABBITMQ_PORT: int = 5672
    RABBITMQ_USER: str = "guest"
    RABBITMQ_PASSWORD: str = "guest"
    RABBITMQ_EXCHANGE: str = "events"

    # JWT Authentication
    JWT_SECRET: str = "your-secret-key-change-in-production"  # Change this!
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 1440  # 24 hours

    # Password Hashing
    BCRYPT_ROUNDS: int = 12

    # Mock Mode
    MOCK_MODE: bool = False

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

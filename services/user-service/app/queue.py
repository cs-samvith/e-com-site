import pika
import json
import logging
from app.config import settings
from app.models import UserEvent

logger = logging.getLogger(__name__)


class QueuePublisher:
    """RabbitMQ publisher for user events"""

    def __init__(self):
        self.connection = None
        self.channel = None

    def connect(self):
        """Establish connection to RabbitMQ"""
        try:
            credentials = pika.PlainCredentials(
                settings.RABBITMQ_USER,
                settings.RABBITMQ_PASSWORD
            )

            parameters = pika.ConnectionParameters(
                host=settings.RABBITMQ_HOST,
                port=settings.RABBITMQ_PORT,
                credentials=credentials,
                heartbeat=600,
                blocked_connection_timeout=300
            )

            self.connection = pika.BlockingConnection(parameters)
            self.channel = self.connection.channel()

            # Declare exchange
            self.channel.exchange_declare(
                exchange=settings.RABBITMQ_EXCHANGE,
                exchange_type='topic',
                durable=True
            )

            logger.info(f"Connected to RabbitMQ: {settings.RABBITMQ_HOST}")
            return True

        except Exception as e:
            logger.error(f"Failed to connect to RabbitMQ: {e}")
            return False

    def publish_event(self, event: UserEvent) -> bool:
        """Publish user event to message queue"""
        if not self.channel:
            if not self.connect():
                logger.warning("Cannot publish event: RabbitMQ not connected")
                return False

        try:
            # Convert event to dict
            event_dict = {
                "event": event.event,
                "timestamp": event.timestamp.isoformat(),
                "data": event.data
            }

            # Determine routing key based on event type
            routing_key = event.event  # e.g., "user.created", "user.login"

            # Publish message
            self.channel.basic_publish(
                exchange=settings.RABBITMQ_EXCHANGE,
                routing_key=routing_key,
                body=json.dumps(event_dict),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # Make message persistent
                    content_type='application/json'
                )
            )

            logger.info(f"Published event: {event.event}")
            return True

        except Exception as e:
            logger.error(f"Failed to publish event: {e}")
            # Try to reconnect
            self.connection = None
            self.channel = None
            return False

    def close(self):
        """Close connection"""
        try:
            if self.connection and self.connection.is_open:
                self.connection.close()
                logger.info("RabbitMQ connection closed")
        except Exception as e:
            logger.error(f"Error closing connection: {e}")

    def health_check(self) -> bool:
        """Check RabbitMQ connection health"""
        try:
            if self.connection and self.connection.is_open:
                return True
            return False
        except Exception:
            return False


# Global queue publisher instance
queue_publisher = QueuePublisher()

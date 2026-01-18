import pika
import json
import logging
import threading
from typing import Callable
from app.config import settings
from app.models import InventoryUpdate
from app.database import db
from app.cache import cache
from uuid import UUID

logger = logging.getLogger(__name__)


class QueueConsumer:
    """RabbitMQ consumer for inventory updates"""
    
    def __init__(self):
        self.connection = None
        self.channel = None
        self.is_consuming = False
        self.consumer_thread = None
    
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
            
            # Declare exchange and queue
            self.channel.exchange_declare(
                exchange='events',
                exchange_type='topic',
                durable=True
            )
            
            self.channel.queue_declare(
                queue=settings.RABBITMQ_QUEUE,
                durable=True
            )
            
            # Bind queue to exchange
            self.channel.queue_bind(
                queue=settings.RABBITMQ_QUEUE,
                exchange='events',
                routing_key='product.inventory.update'
            )
            
            # Set QoS - process one message at a time
            self.channel.basic_qos(prefetch_count=1)
            
            logger.info(f"Connected to RabbitMQ: {settings.RABBITMQ_HOST}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect to RabbitMQ: {e}")
            return False
    
    def callback(self, ch, method, properties, body):
        """Process inventory update message"""
        try:
            # Parse message
            message = json.loads(body)
            logger.info(f"Received inventory update: {message}")
            
            # Extract data
            inventory_update = InventoryUpdate(**message['data'])
            
            # Simulate processing time (remove in production)
            import time
            time.sleep(2)
            
            # Update inventory in database
            product = db.get_product_by_id(inventory_update.product_id)
            if product:
                from app.models import ProductUpdate
                update = ProductUpdate(inventory_count=inventory_update.new_count)
                updated_product = db.update_product(inventory_update.product_id, update)
                
                if updated_product:
                    # Invalidate cache
                    cache.delete_product(inventory_update.product_id)
                    logger.info(f"Updated inventory for product {inventory_update.product_id}: "
                              f"{inventory_update.old_count} → {inventory_update.new_count}")
                else:
                    logger.warning(f"Failed to update product {inventory_update.product_id}")
            else:
                logger.warning(f"Product {inventory_update.product_id} not found")
            
            # Acknowledge message
            ch.basic_ack(delivery_tag=method.delivery_tag)
            logger.info("Message processed and acknowledged")
            
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            # Reject and requeue message
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
    
    def start_consuming(self):
        """Start consuming messages in a separate thread"""
        if self.is_consuming:
            logger.warning("Already consuming messages")
            return
        
        if not self.connect():
            logger.error("Cannot start consuming: connection failed")
            return
        
        def consume():
            try:
                self.is_consuming = True
                logger.info(f"Started consuming from queue: {settings.RABBITMQ_QUEUE}")
                
                self.channel.basic_consume(
                    queue=settings.RABBITMQ_QUEUE,
                    on_message_callback=self.callback,
                    auto_ack=False
                )
                
                self.channel.start_consuming()
                
            except Exception as e:
                logger.error(f"Consumer error: {e}")
                self.is_consuming = False
        
        # Start consumer in separate thread
        self.consumer_thread = threading.Thread(target=consume, daemon=True)
        self.consumer_thread.start()
        logger.info("Consumer thread started")
    
    def stop_consuming(self):
        """Stop consuming messages"""
        if not self.is_consuming:
            return
        
        try:
            self.is_consuming = False
            if self.channel:
                self.channel.stop_consuming()
            if self.connection:
                self.connection.close()
            logger.info("Stopped consuming messages")
        except Exception as e:
            logger.error(f"Error stopping consumer: {e}")
    
    def health_check(self) -> bool:
        """Check RabbitMQ connection health"""
        try:
            if self.connection and self.connection.is_open:
                return True
            return False
        except Exception:
            return False
    
    def get_queue_depth(self) -> int:
        """Get current queue depth (for KEDA metrics)"""
        try:
            if not self.channel:
                return 0
            
            method_frame = self.channel.queue_declare(
                queue=settings.RABBITMQ_QUEUE,
                passive=True
            )
            return method_frame.method.message_count
        except Exception as e:
            logger.error(f"Failed to get queue depth: {e}")
            return 0


# Global queue consumer instance
queue_consumer = QueueConsumer()

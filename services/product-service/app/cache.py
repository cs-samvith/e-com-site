import redis
import json
import logging
from typing import Optional
from uuid import UUID
from app.config import settings
from app.models import Product

logger = logging.getLogger(__name__)


class Cache:
    """Redis cache handler"""
    
    def __init__(self):
        try:
            self.client = redis.Redis(
                host=settings.REDIS_HOST,
                port=settings.REDIS_PORT,
                password=settings.REDIS_PASSWORD,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5
            )
            # Test connection
            self.client.ping()
            logger.info("Redis connection established")
        except Exception as e:
            logger.warning(f"Redis connection failed: {e}. Cache disabled.")
            self.client = None
    
    def get_product(self, product_id: UUID) -> Optional[Product]:
        """Get product from cache"""
        if not self.client:
            return None
        
        try:
            key = f"product:{product_id}"
            data = self.client.get(key)
            
            if data:
                logger.info(f"Cache HIT for product {product_id}")
                product_dict = json.loads(data)
                return Product(**product_dict)
            
            logger.info(f"Cache MISS for product {product_id}")
            return None
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None
    
    def set_product(self, product: Product) -> bool:
        """Set product in cache"""
        if not self.client:
            return False
        
        try:
            key = f"product:{product.id}"
            # Convert product to dict and handle datetime serialization
            product_dict = product.model_dump()
            product_dict['id'] = str(product_dict['id'])
            product_dict['created_at'] = product_dict['created_at'].isoformat()
            product_dict['updated_at'] = product_dict['updated_at'].isoformat()
            
            data = json.dumps(product_dict)
            self.client.setex(key, settings.CACHE_TTL, data)
            
            logger.info(f"Cached product {product.id} for {settings.CACHE_TTL}s")
            return True
        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False
    
    def delete_product(self, product_id: UUID) -> bool:
        """Delete product from cache"""
        if not self.client:
            return False
        
        try:
            key = f"product:{product_id}"
            deleted = self.client.delete(key)
            
            if deleted:
                logger.info(f"Deleted product {product_id} from cache")
            return bool(deleted)
        except Exception as e:
            logger.error(f"Cache delete error: {e}")
            return False
    
    def invalidate_all_products(self) -> int:
        """Invalidate all product cache entries"""
        if not self.client:
            return 0
        
        try:
            keys = self.client.keys("product:*")
            if keys:
                deleted = self.client.delete(*keys)
                logger.info(f"Invalidated {deleted} product cache entries")
                return deleted
            return 0
        except Exception as e:
            logger.error(f"Cache invalidation error: {e}")
            return 0
    
    def get_cache_stats(self) -> dict:
        """Get cache statistics"""
        if not self.client:
            return {"status": "disabled"}
        
        try:
            info = self.client.info("stats")
            return {
                "status": "healthy",
                "hits": info.get("keyspace_hits", 0),
                "misses": info.get("keyspace_misses", 0),
                "keys": len(self.client.keys("product:*")),
                "memory_used": info.get("used_memory_human", "N/A")
            }
        except Exception as e:
            logger.error(f"Failed to get cache stats: {e}")
            return {"status": "error", "error": str(e)}
    
    def health_check(self) -> bool:
        """Check Redis health"""
        if not self.client:
            return False
        
        try:
            return self.client.ping()
        except Exception:
            return False


# Global cache instance
cache = Cache()

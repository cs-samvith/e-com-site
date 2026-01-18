from app.queue import queue_consumer
from app.cache import cache
from app.models import Product, ProductCreate, ProductUpdate, HealthResponse
from app.config import settings
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse, Response
from typing import List, Optional
from uuid import UUID
import logging
from datetime import datetime
from prometheus_client import Counter, Histogram, Gauge, generate_latest

# Configure logging FIRST (before using logger)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Import app modules

# Determine which database to use
if settings.MOCK_MODE:
    # Explicitly using mock mode
    logger.info("MOCK_MODE=True: Using mock in-memory database")
    from app.mock_database import MockDatabase
    db = MockDatabase()
    USE_REAL_DB = False
elif settings.DB_HOST in ['postgres-service']:
    # Kubernetes service name - use mock for local development
    logger.info(f"DB_HOST={settings.DB_HOST}: Using mock in-memory database")
    from app.mock_database import MockDatabase
    db = MockDatabase()
    USE_REAL_DB = False
else:
    # Try to use real database (localhost or custom host)
    try:
        logger.info(
            f"Attempting to connect to PostgreSQL at {settings.DB_HOST}:{settings.DB_PORT}")
        from app.database import db
        # Test connection
        if db.health_check():
            logger.info("✓ Connected to PostgreSQL - using real database")
            USE_REAL_DB = True
        else:
            logger.warning(
                "PostgreSQL health check failed - using mock database")
            from app.mock_database import MockDatabase
            db = MockDatabase()
            USE_REAL_DB = False
    except Exception as e:
        logger.warning(
            f"Failed to initialize PostgreSQL: {e}. Using mock database.")
        from app.mock_database import MockDatabase
        db = MockDatabase()
        USE_REAL_DB = False


# Prometheus metrics
REQUEST_COUNT = Counter(
    'product_service_requests_total',
    'Total requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'product_service_request_duration_seconds',
    'Request latency',
    ['method', 'endpoint']
)

PRODUCTS_CACHED = Gauge(
    'product_service_cached_products',
    'Number of products in cache'
)

QUEUE_DEPTH = Gauge(
    'product_service_queue_depth',
    'RabbitMQ queue depth'
)

# Create FastAPI app
app = FastAPI(
    title="Product Service",
    description="Microservice for product catalog and inventory",
    version="1.0.0"
)


@app.on_event("startup")
async def startup_event():
    """Initialize service on startup"""
    logger.info(f"Starting {settings.SERVICE_NAME}...")

    # Initialize database
    try:
        db.init_db()
        logger.info("Database initialized")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")

    # Start RabbitMQ consumer
    try:
        queue_consumer.start_consuming()
        logger.info("Queue consumer started")
    except Exception as e:
        logger.error(f"Failed to start queue consumer: {e}")

    logger.info(
        f"{settings.SERVICE_NAME} started successfully on port {settings.SERVICE_PORT}")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down...")
    queue_consumer.stop_consuming()


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": settings.SERVICE_NAME,
        "status": "running",
        "version": "1.0.0",
        "endpoints": {
            "health": "/healthz",
            "ready": "/ready",
            "metrics": "/metrics",
            "products": "/api/products",
            "docs": "/docs"
        }
    }


@app.get("/healthz", response_model=HealthResponse)
async def health_check():
    """
    Liveness probe - is the service alive?
    Used by Kubernetes to restart unhealthy pods
    """
    return HealthResponse(
        status="healthy",
        service=settings.SERVICE_NAME
    )


@app.get("/ready", response_model=HealthResponse)
async def readiness_check():
    """
    Readiness probe - is the service ready to accept traffic?
    Used by Kubernetes to route traffic
    """
    dependencies = {
        "database": db.health_check(),
        "cache": cache.health_check(),
        "queue": queue_consumer.health_check()
    }

    # Service is ready if database is healthy (minimum requirement)
    is_ready = dependencies["database"]

    return HealthResponse(
        status="ready" if is_ready else "not_ready",
        service=settings.SERVICE_NAME,
        dependencies=dependencies
    )


@app.get("/metrics")
async def metrics():
    """
    Prometheus metrics endpoint
    Scraped by Prometheus for monitoring
    """
    # Update queue depth metric
    try:
        QUEUE_DEPTH.set(queue_consumer.get_queue_depth())
    except Exception:
        pass

    return Response(content=generate_latest(), media_type="text/plain")


@app.get("/api/products", response_model=List[Product])
async def get_products(
    limit: int = Query(default=100, ge=1, le=1000),
    offset: int = Query(default=0, ge=0)
):
    """
    Get all products with pagination
    """
    try:
        with REQUEST_LATENCY.labels(method="GET", endpoint="/api/products").time():
            products = db.get_products(limit=limit, offset=offset)

        REQUEST_COUNT.labels(
            method="GET", endpoint="/api/products", status="200").inc()
        logger.info(f"Retrieved {len(products)} products")
        return products

    except Exception as e:
        REQUEST_COUNT.labels(
            method="GET", endpoint="/api/products", status="500").inc()
        logger.error(f"Error getting products: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/api/products/search/", response_model=List[Product])
async def search_products(q: str = Query(..., min_length=1)):
    """
    Search products by name or description
    IMPORTANT: This route must come BEFORE /api/products/{product_id}
    """
    try:
        with REQUEST_LATENCY.labels(method="GET", endpoint="/api/products/search").time():
            products = db.search_products(q)

        REQUEST_COUNT.labels(
            method="GET", endpoint="/api/products/search", status="200").inc()
        logger.info(f"Search for '{q}' returned {len(products)} results")
        return products

    except Exception as e:
        REQUEST_COUNT.labels(
            method="GET", endpoint="/api/products/search", status="500").inc()
        logger.error(f"Error searching products: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/api/products/{product_id}", response_model=Product)
async def get_product(product_id: UUID):
    """
    Get product by ID
    Uses cache if available
    """
    try:
        with REQUEST_LATENCY.labels(method="GET", endpoint="/api/products/{id}").time():
            # Try cache first
            product = cache.get_product(product_id)

            if not product:
                # Cache miss - get from database
                product = db.get_product_by_id(product_id)

                if not product:
                    REQUEST_COUNT.labels(
                        method="GET",
                        endpoint="/api/products/{id}",
                        status="404"
                    ).inc()
                    raise HTTPException(
                        status_code=404, detail="Product not found")

                # Store in cache for next time
                cache.set_product(product)

        REQUEST_COUNT.labels(
            method="GET", endpoint="/api/products/{id}", status="200").inc()
        logger.info(f"Retrieved product {product_id}")
        return product

    except HTTPException:
        raise
    except Exception as e:
        REQUEST_COUNT.labels(
            method="GET", endpoint="/api/products/{id}", status="500").inc()
        logger.error(f"Error getting product {product_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.post("/api/products", response_model=Product, status_code=201)
async def create_product(product: ProductCreate):
    """
    Create a new product
    (Admin only - in real app would check auth)
    """
    try:
        with REQUEST_LATENCY.labels(method="POST", endpoint="/api/products").time():
            new_product = db.create_product(product)

            # Store in cache
            cache.set_product(new_product)

        REQUEST_COUNT.labels(
            method="POST", endpoint="/api/products", status="201").inc()
        logger.info(f"Created product {new_product.id}")
        return new_product

    except Exception as e:
        REQUEST_COUNT.labels(
            method="POST", endpoint="/api/products", status="500").inc()
        logger.error(f"Error creating product: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.put("/api/products/{product_id}", response_model=Product)
async def update_product(product_id: UUID, product_update: ProductUpdate):
    """
    Update a product
    (Admin only - in real app would check auth)
    """
    try:
        with REQUEST_LATENCY.labels(method="PUT", endpoint="/api/products/{id}").time():
            updated_product = db.update_product(product_id, product_update)

            if not updated_product:
                REQUEST_COUNT.labels(
                    method="PUT",
                    endpoint="/api/products/{id}",
                    status="404"
                ).inc()
                raise HTTPException(
                    status_code=404, detail="Product not found")

            # Update cache
            cache.set_product(updated_product)

        REQUEST_COUNT.labels(
            method="PUT", endpoint="/api/products/{id}", status="200").inc()
        logger.info(f"Updated product {product_id}")
        return updated_product

    except HTTPException:
        raise
    except Exception as e:
        REQUEST_COUNT.labels(
            method="PUT", endpoint="/api/products/{id}", status="500").inc()
        logger.error(f"Error updating product {product_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.delete("/api/products/{product_id}", status_code=204)
async def delete_product(product_id: UUID):
    """
    Delete a product
    (Admin only - in real app would check auth)
    """
    try:
        with REQUEST_LATENCY.labels(method="DELETE", endpoint="/api/products/{id}").time():
            deleted = db.delete_product(product_id)

            if not deleted:
                REQUEST_COUNT.labels(
                    method="DELETE",
                    endpoint="/api/products/{id}",
                    status="404"
                ).inc()
                raise HTTPException(
                    status_code=404, detail="Product not found")

            # Remove from cache
            cache.delete_product(product_id)

        REQUEST_COUNT.labels(
            method="DELETE", endpoint="/api/products/{id}", status="204").inc()
        logger.info(f"Deleted product {product_id}")
        return Response(status_code=204)

    except HTTPException:
        raise
    except Exception as e:
        REQUEST_COUNT.labels(
            method="DELETE", endpoint="/api/products/{id}", status="500").inc()
        logger.error(f"Error deleting product {product_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/api/products/{product_id}/inventory")
async def get_inventory(product_id: UUID):
    """
    Get product inventory count
    """
    try:
        product = db.get_product_by_id(product_id)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        return {
            "product_id": product.id,
            "inventory_count": product.inventory_count,
            "last_updated": product.updated_at
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting inventory: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/debug/cache-stats")
async def get_cache_stats():
    """
    Get cache statistics (for debugging)
    """
    return cache.get_cache_stats()


@app.post("/debug/invalidate-cache")
async def invalidate_cache():
    """
    Invalidate all cache entries (for debugging)
    """
    deleted = cache.invalidate_all_products()
    return {"message": f"Invalidated {deleted} cache entries"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=settings.SERVICE_PORT,
        reload=False,
        log_level="info"
    )

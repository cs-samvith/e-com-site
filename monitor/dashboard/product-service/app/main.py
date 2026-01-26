"""
Product Service - FastAPI Application with Metrics
Example integration of Prometheus metrics into FastAPI
"""

from fastapi import FastAPI, Response, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import uvicorn
import time

# Import our metrics module
from .metrics import (
    get_metrics,
    track_product_view,
    track_add_to_cart,
    track_product_search,
    update_product_inventory,
    update_product_price,
    track_endpoint_metrics,
    track_database_query,
    track_cache_operation,
    http_requests_total,
    http_request_duration_seconds,
)

# Initialize FastAPI app
app = FastAPI(
    title="Product Service",
    description="E-Commerce Product Management Service with Prometheus Metrics",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =============================================================================
# Middleware for automatic metrics tracking
# =============================================================================


@app.middleware("http")
async def track_requests(request: Request, call_next):
    """Middleware to automatically track all HTTP requests"""
    start_time = time.time()

    # Process the request
    response = await call_next(request)

    # Calculate duration
    duration = time.time() - start_time

    # Track metrics
    http_requests_total.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()

    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)

    return response

# =============================================================================
# Pydantic Models
# =============================================================================


class Product(BaseModel):
    id: str
    name: str
    description: str
    price: float
    category: str
    inventory: int
    image_url: Optional[str] = None


class ProductSearch(BaseModel):
    query: str
    category: Optional[str] = None
    min_price: Optional[float] = None
    max_price: Optional[float] = None


class CartItem(BaseModel):
    product_id: str
    quantity: int

# =============================================================================
# Prometheus Metrics Endpoint
# =============================================================================


@app.get("/metrics")
async def metrics():
    """
    Prometheus metrics endpoint
    This endpoint exposes all metrics in Prometheus format
    """
    return Response(content=get_metrics(), media_type="text/plain")

# =============================================================================
# Health Check Endpoints
# =============================================================================


@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes liveness probe"""
    return {"status": "healthy", "service": "product-service"}


@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint for Kubernetes readiness probe"""
    # Add checks for database, cache, etc.
    return {"status": "ready", "service": "product-service"}

# =============================================================================
# Product Endpoints with Metrics
# =============================================================================


@app.get("/products/{product_id}")
@track_endpoint_metrics("get_product")
async def get_product(product_id: str):
    """
    Get a single product by ID
    Tracks: product views
    """
    # Simulate database query (replace with real DB call)
    product = {
        "id": product_id,
        "name": "Sample Product",
        "description": "This is a sample product",
        "price": 29.99,
        "category": "Electronics",
        "inventory": 100
    }

    # Track the product view
    track_product_view(
        product_id=product["id"],
        product_name=product["name"],
        category=product["category"]
    )

    return product


@app.get("/products")
@track_endpoint_metrics("list_products")
async def list_products(
    category: Optional[str] = None,
    limit: int = 20,
    offset: int = 0
):
    """
    List products with optional filtering
    """
    # Simulate database query
    products = [
        {
            "id": f"prod-{i}",
            "name": f"Product {i}",
            "price": 29.99 + i,
            "category": category or "General",
            "inventory": 100 - i
        }
        for i in range(offset, offset + limit)
    ]

    return {
        "products": products,
        "total": 1000,
        "limit": limit,
        "offset": offset
    }


@app.post("/products/search")
@track_endpoint_metrics("search_products")
async def search_products(search: ProductSearch):
    """
    Search for products
    Tracks: search queries
    """
    # Track search query
    if search.category:
        track_product_search("category")
    else:
        track_product_search("full_text")

    # Simulate search (replace with real search logic)
    results = [
        {
            "id": "prod-1",
            "name": f"Product matching '{search.query}'",
            "price": 39.99,
            "category": "Electronics",
            "relevance_score": 0.95
        }
    ]

    return {"results": results, "total": len(results)}


@app.post("/cart/add")
@track_endpoint_metrics("add_to_cart")
async def add_to_cart(item: CartItem):
    """
    Add product to cart
    Tracks: add to cart actions
    """
    # Get product details (simulated)
    product_name = f"Product {item.product_id}"

    # Track the add to cart action
    track_add_to_cart(
        product_id=item.product_id,
        product_name=product_name
    )

    return {
        "message": "Product added to cart",
        "product_id": item.product_id,
        "quantity": item.quantity
    }


@app.post("/products")
@track_endpoint_metrics("create_product")
async def create_product(product: Product):
    """
    Create a new product
    Tracks: product creation, inventory updates
    """
    # Simulate product creation

    # Update inventory and price metrics
    update_product_inventory(
        product_id=product.id,
        product_name=product.name,
        quantity=product.inventory
    )

    update_product_price(
        product_id=product.id,
        product_name=product.name,
        price=product.price,
        currency="USD"
    )

    return {"message": "Product created", "product": product}


@app.put("/products/{product_id}/inventory")
@track_endpoint_metrics("update_inventory")
async def update_inventory(product_id: str, quantity: int):
    """
    Update product inventory
    Tracks: inventory level changes
    """
    # Update inventory
    update_product_inventory(
        product_id=product_id,
        product_name=f"Product {product_id}",
        quantity=quantity
    )

    return {
        "message": "Inventory updated",
        "product_id": product_id,
        "new_quantity": quantity
    }


@app.put("/products/{product_id}/price")
@track_endpoint_metrics("update_price")
async def update_price(product_id: str, price: float):
    """
    Update product price
    Tracks: price changes
    """
    # Update price
    update_product_price(
        product_id=product_id,
        product_name=f"Product {product_id}",
        price=price,
        currency="USD"
    )

    return {
        "message": "Price updated",
        "product_id": product_id,
        "new_price": price
    }

# =============================================================================
# Example: Database Query with Metrics
# =============================================================================


@track_database_query("select", "products")
async def get_product_from_db(product_id: str):
    """
    Example function showing database query tracking
    """
    # Simulate database query
    await asyncio.sleep(0.01)  # Simulate DB latency
    return {"id": product_id, "name": "Sample Product"}

# =============================================================================
# Example: Cache Operation with Metrics
# =============================================================================


@track_cache_operation("get", "product")
async def get_product_from_cache(product_id: str):
    """
    Example function showing cache operation tracking
    """
    # Simulate cache lookup
    # Return None for cache miss
    return None

# =============================================================================
# Startup Event - Initialize Metrics
# =============================================================================


@app.on_event("startup")
async def startup_event():
    """Initialize metrics on startup"""
    print("🚀 Product Service started")
    print("📊 Metrics available at /metrics")

    # Initialize some default metrics
    # This is useful for establishing baseline metrics
    for i in range(1, 6):
        update_product_inventory(
            product_id=f"prod-{i}",
            product_name=f"Sample Product {i}",
            quantity=100
        )
        update_product_price(
            product_id=f"prod-{i}",
            product_name=f"Sample Product {i}",
            price=29.99 * i,
            currency="USD"
        )

# =============================================================================
# Main Entry Point
# =============================================================================

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8080,
        reload=True
    )

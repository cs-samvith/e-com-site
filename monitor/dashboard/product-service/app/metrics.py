from prometheus_client import Counter, Histogram, Gauge, generate_latest
from functools import wraps
import time
//services/product-service/app/metrics.py


"""
E-Commerce Metrics Instrumentation for Product Service
Tracks business metrics and technical metrics for Prometheus
"""


# =============================================================================
# Business Metrics - Product Service
# =============================================================================

# Product Views
product_views_total = Counter(
    'product_views_total',
    'Total number of product views',
    ['product_id', 'product_name', 'category']
)

# Products Added to Cart
products_added_to_cart_total = Counter(
    'products_added_to_cart_total',
    'Total number of products added to cart',
    ['product_id', 'product_name']
)

# Product Search
product_search_queries_total = Counter(
    'product_search_queries_total',
    'Total number of product search queries',
    ['search_type']  # full_text, filter, category
)

# Product Inventory
product_inventory_level = Gauge(
    'product_inventory_level',
    'Current inventory level for products',
    ['product_id', 'product_name']
)

# Product Price
product_current_price = Gauge(
    'product_current_price',
    'Current price of products',
    ['product_id', 'product_name', 'currency']
)

# =============================================================================
# Technical Metrics - HTTP
# =============================================================================

# HTTP Request Count
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

# HTTP Request Duration
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
)

# =============================================================================
# Database Metrics
# =============================================================================

# Database Query Duration
database_query_duration_seconds = Histogram(
    'database_query_duration_seconds',
    'Database query duration in seconds',
    ['operation', 'table'],
    buckets=[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0]
)

# Database Connections
database_connections_active = Gauge(
    'database_connections_active',
    'Number of active database connections'
)

database_connections_idle = Gauge(
    'database_connections_idle',
    'Number of idle database connections'
)

database_connections_max = Gauge(
    'database_connections_max',
    'Maximum number of database connections'
)

# =============================================================================
# Cache Metrics
# =============================================================================

# Redis Cache Hits/Misses
redis_cache_hits_total = Counter(
    'redis_cache_hits_total',
    'Total number of cache hits',
    ['cache_key_type']
)

redis_cache_misses_total = Counter(
    'redis_cache_misses_total',
    'Total number of cache misses',
    ['cache_key_type']
)

# Redis Operations
redis_operations_total = Counter(
    'redis_operations_total',
    'Total Redis operations',
    ['operation']  # get, set, delete, expire
)

# Cache Operation Duration
redis_operation_duration_seconds = Histogram(
    'redis_operation_duration_seconds',
    'Redis operation duration in seconds',
    ['operation'],
    buckets=[0.001, 0.005, 0.01, 0.05, 0.1]
)

# =============================================================================
# Decorator Functions
# =============================================================================


def track_endpoint_metrics(endpoint_name):
    """Decorator to track HTTP endpoint metrics"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            start_time = time.time()
            status_code = 200

            try:
                response = await func(*args, **kwargs)
                if hasattr(response, 'status_code'):
                    status_code = response.status_code
                return response
            except Exception as e:
                status_code = 500
                raise
            finally:
                duration = time.time() - start_time

                # Track request count
                http_requests_total.labels(
                    method='GET',  # or extract from request
                    endpoint=endpoint_name,
                    status=status_code
                ).inc()

                # Track request duration
                http_request_duration_seconds.labels(
                    method='GET',
                    endpoint=endpoint_name
                ).observe(duration)

        return wrapper
    return decorator


def track_database_query(operation, table):
    """Decorator to track database query metrics"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            start_time = time.time()

            try:
                result = await func(*args, **kwargs)
                return result
            finally:
                duration = time.time() - start_time
                database_query_duration_seconds.labels(
                    operation=operation,
                    table=table
                ).observe(duration)

        return wrapper
    return decorator


def track_cache_operation(operation, key_type):
    """Decorator to track cache operations"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            start_time = time.time()

            try:
                result = await func(*args, **kwargs)

                # Track hit/miss for get operations
                if operation == 'get':
                    if result is not None:
                        redis_cache_hits_total.labels(
                            cache_key_type=key_type
                        ).inc()
                    else:
                        redis_cache_misses_total.labels(
                            cache_key_type=key_type
                        ).inc()

                return result
            finally:
                duration = time.time() - start_time

                # Track operation count and duration
                redis_operations_total.labels(operation=operation).inc()
                redis_operation_duration_seconds.labels(
                    operation=operation
                ).observe(duration)

        return wrapper
    return decorator


# =============================================================================
# Helper Functions
# =============================================================================

def track_product_view(product_id: str, product_name: str, category: str):
    """Track a product view"""
    product_views_total.labels(
        product_id=product_id,
        product_name=product_name,
        category=category
    ).inc()


def track_add_to_cart(product_id: str, product_name: str):
    """Track adding a product to cart"""
    products_added_to_cart_total.labels(
        product_id=product_id,
        product_name=product_name
    ).inc()


def track_product_search(search_type: str):
    """Track a product search"""
    product_search_queries_total.labels(
        search_type=search_type
    ).inc()


def update_product_inventory(product_id: str, product_name: str, quantity: int):
    """Update product inventory level"""
    product_inventory_level.labels(
        product_id=product_id,
        product_name=product_name
    ).set(quantity)


def update_product_price(product_id: str, product_name: str, price: float, currency: str = 'USD'):
    """Update product price"""
    product_current_price.labels(
        product_id=product_id,
        product_name=product_name,
        currency=currency
    ).set(price)


def update_db_connection_stats(active: int, idle: int, max_conn: int):
    """Update database connection statistics"""
    database_connections_active.set(active)
    database_connections_idle.set(idle)
    database_connections_max.set(max_conn)


# =============================================================================
# Metrics Endpoint
# =============================================================================

def get_metrics():
    """Return Prometheus metrics in text format"""
    return generate_latest()

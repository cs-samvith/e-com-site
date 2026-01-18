# Product Service

A simple microservice for product catalog and inventory management, designed to demonstrate Kubernetes concepts.

## Features

- **RESTful API** for product CRUD operations
- **PostgreSQL** for data persistence (optional - falls back to in-memory)
- **Redis** caching for improved performance (optional - gracefully disabled if unavailable)
- **RabbitMQ** consumer for async inventory updates (optional)
- **Prometheus** metrics for monitoring
- **Health checks** for Kubernetes probes
- **KEDA** event-driven autoscaling (based on queue depth)
- **Graceful degradation** - works without any dependencies!

## Quick Start (No Dependencies Required!)

The service gracefully handles missing dependencies and can run standalone:

```bash
# 1. Create virtual environment (recommended)
python -m venv venv

# 2. Activate virtual environment
# Windows Command Prompt:
venv\Scripts\activate.bat
# Windows PowerShell:
venv\Scripts\Activate.ps1
# Linux/Mac:
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Run the service (uses in-memory mock database)
python -m uvicorn app.main:app --reload --port 8081

# 5. Test it
curl http://localhost:8081/api/products
# Or open in browser: http://localhost:8081/api/products
```

**Requirements:**

- Python 3.11 or 3.12 (Python 3.13+ requires updated packages)
- Use updated requirements.txt with pydantic 2.10.3

**What happens:**

- ✅ Service starts successfully
- ✅ Uses in-memory mock database (10 sample products)
- ✅ All API endpoints work
- ⚠️ Logs warnings about missing dependencies
- ⚠️ Data not persisted (lost on restart)

---

## Running Options

### Option 1: Standalone (No Dependencies) ⚡ Fastest

Perfect for quick testing and learning K8s concepts without infrastructure setup.

```bash
# Install minimal dependencies
pip install fastapi uvicorn pydantic pydantic-settings prometheus-client python-json-logger

# Run
python -m uvicorn app.main:app --reload --port 8081
```

**Features:**

- ✅ Starts in seconds
- ✅ 10 mock products pre-loaded
- ✅ All CRUD operations work
- ⚠️ In-memory only (data lost on restart)
- ⚠️ No caching
- ⚠️ No queue processing

---

### Option 2: With PostgreSQL Only 🗄️

Add persistent database while keeping it simple.

```bash
# 1. Start PostgreSQL
docker run -d \
  --name postgres-local \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=products_db \
  -p 5432:5432 \
  postgres:15

# 2. Install all dependencies
pip install -r requirements.txt

# 3. Run service
export DB_HOST=localhost
python -m uvicorn app.main:app --reload --port 8081
```

**Features:**

- ✅ Persistent data storage
- ✅ All CRUD operations
- ⚠️ No caching (slower reads)
- ⚠️ No queue processing

---

### Option 3: Full Stack (Docker Compose) 🚀 Recommended

Complete setup with all dependencies for full functionality.

```bash
# Start everything
docker-compose up -d

# View logs
docker-compose logs -f product-service

# Stop everything
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

**Features:**

- ✅ PostgreSQL (persistent storage)
- ✅ Redis (caching for performance)
- ✅ RabbitMQ (async message processing)
- ✅ Product Service
- ✅ All features enabled

**Access:**

- Product API: http://localhost:8081/api/products
- RabbitMQ UI: http://localhost:15672 (guest/guest)
- Health: http://localhost:8081/healthz
- Metrics: http://localhost:8081/metrics

---

### Option 4: Individual Dependencies

Mix and match based on what you want to test:

```bash
# PostgreSQL + Redis (persistence + caching)
docker run -d --name postgres-local \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=products_db \
  -p 5432:5432 postgres:15

docker run -d --name redis-local \
  -p 6379:6379 redis:7-alpine

pip install -r requirements.txt
export DB_HOST=localhost
export REDIS_HOST=localhost
python -m uvicorn app.main:app --reload --port 8081
```

---

## API Endpoints

### Products

| Method | Endpoint                       | Description                   | Example              |
| ------ | ------------------------------ | ----------------------------- | -------------------- |
| GET    | `/api/products`                | List all products (paginated) | `?limit=10&offset=0` |
| GET    | `/api/products/search/`        | Search products               | `?q=laptop`          |
| GET    | `/api/products/{id}`           | Get product by ID             | -                    |
| POST   | `/api/products`                | Create new product            | See body below       |
| PUT    | `/api/products/{id}`           | Update product                | See body below       |
| DELETE | `/api/products/{id}`           | Delete product                | -                    |
| GET    | `/api/products/{id}/inventory` | Get inventory count           | -                    |

**Note:** Search endpoint must include trailing slash: `/api/products/search/`

### Health & Monitoring

| Method | Endpoint                  | Description                          |
| ------ | ------------------------- | ------------------------------------ |
| GET    | `/`                       | Service info and available endpoints |
| GET    | `/healthz`                | Liveness probe (K8s)                 |
| GET    | `/ready`                  | Readiness probe (K8s)                |
| GET    | `/metrics`                | Prometheus metrics                   |
| GET    | `/docs`                   | Interactive API documentation        |
| GET    | `/debug/cache-stats`      | Cache statistics                     |
| POST   | `/debug/invalidate-cache` | Clear cache                          |

---

## API Examples

### Get All Products

```bash
curl http://localhost:8081/api/products
```

### Get Product by ID

```bash
# First, get a product ID from the list
PRODUCT_ID="<copy-id-from-above>"

curl http://localhost:8081/api/products/$PRODUCT_ID
```

### Create Product

```bash
curl -X POST http://localhost:8081/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Gaming Laptop",
    "description": "High-performance gaming laptop with RTX 4090",
    "price": 2499.99,
    "category": "Electronics",
    "inventory_count": 25
  }'
```

### Update Product

```bash
curl -X PUT http://localhost:8081/api/products/$PRODUCT_ID \
  -H "Content-Type: application/json" \
  -d '{
    "price": 1999.99,
    "inventory_count": 30
  }'
```

### Delete Product

```bash
curl -X DELETE http://localhost:8081/api/products/$PRODUCT_ID
```

### Search Products

```bash
# Note: Include trailing slash
curl "http://localhost:8081/api/products/search/?q=laptop"

# Or in browser
http://localhost:8081/api/products/search/?q=laptop
```

### Health Check

```bash
curl http://localhost:8081/healthz
```

### Prometheus Metrics

```bash
curl http://localhost:8081/metrics
```

---

## Testing with Python

```python
import requests

# Base URL
BASE_URL = "http://localhost:8081"

# Get all products
response = requests.get(f"{BASE_URL}/api/products")
products = response.json()
print(f"Found {len(products)} products")

# Get first product
product_id = products[0]["id"]
response = requests.get(f"{BASE_URL}/api/products/{product_id}")
product = response.json()
print(f"Product: {product['name']} - ${product['price']}")

# Create new product
new_product = {
    "name": "Test Product",
    "description": "A test product",
    "price": 99.99,
    "category": "Test",
    "inventory_count": 100
}
response = requests.post(f"{BASE_URL}/api/products", json=new_product)
created = response.json()
print(f"Created product: {created['id']}")

# Search
response = requests.get(f"{BASE_URL}/api/products/search?q=laptop")
results = response.json()
print(f"Search found {len(results)} products")
```

---

## Environment Variables

| Variable            | Default             | Description         |
| ------------------- | ------------------- | ------------------- |
| `SERVICE_NAME`      | `product-service`   | Service name        |
| `SERVICE_PORT`      | `8081`              | Service port        |
| `DB_HOST`           | `postgres-service`  | PostgreSQL host     |
| `DB_PORT`           | `5432`              | PostgreSQL port     |
| `DB_NAME`           | `products_db`       | Database name       |
| `DB_USER`           | `postgres`          | Database user       |
| `DB_PASSWORD`       | `postgres`          | Database password   |
| `REDIS_HOST`        | `redis-service`     | Redis host          |
| `REDIS_PORT`        | `6379`              | Redis port          |
| `REDIS_PASSWORD`    | `None`              | Redis password      |
| `CACHE_TTL`         | `300`               | Cache TTL (seconds) |
| `RABBITMQ_HOST`     | `rabbitmq-service`  | RabbitMQ host       |
| `RABBITMQ_PORT`     | `5672`              | RabbitMQ port       |
| `RABBITMQ_USER`     | `guest`             | RabbitMQ user       |
| `RABBITMQ_PASSWORD` | `guest`             | RabbitMQ password   |
| `RABBITMQ_QUEUE`    | `inventory.updates` | Queue name          |

---

## Docker Compose Setup

The `docker-compose.yml` includes:

### Services

1. **PostgreSQL** (Port 5432)
   - Database: `products_db`
   - User: `postgres`
   - Password: `postgres`
   - Volume: `postgres_data` (persists data)

2. **Redis** (Port 6379)
   - Cache for improved performance
   - No persistence (in-memory)

3. **RabbitMQ** (Ports 5672, 15672)
   - Message queue for async processing
   - Management UI: http://localhost:15672
   - Credentials: guest/guest

4. **Product Service** (Port 8081)
   - Main application
   - Depends on all above services
   - Auto-restarts on failure

### Commands

```bash
# Start all services
docker-compose up -d

# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f product-service

# Check service status
docker-compose ps

# Restart a service
docker-compose restart product-service

# Stop all services
docker-compose down

# Stop and remove all data
docker-compose down -v

# Rebuild and restart
docker-compose up -d --build
```

---

## Docker Build & Run

### Build Image

```bash
docker build -t product-service:latest .
```

### Run Container (Standalone)

```bash
docker run -d \
  --name product-service \
  -p 8081:8081 \
  product-service:latest
```

### Run with External Dependencies

```bash
docker run -d \
  --name product-service \
  -p 8081:8081 \
  -e DB_HOST=host.docker.internal \
  -e REDIS_HOST=host.docker.internal \
  -e RABBITMQ_HOST=host.docker.internal \
  product-service:latest
```

---

## Mock Data

On first startup, the service automatically creates 10 sample products:

| Product       | Price   | Category    | Inventory |
| ------------- | ------- | ----------- | --------- |
| Laptop        | $999.99 | Electronics | 50        |
| Mouse         | $29.99  | Electronics | 200       |
| Keyboard      | $79.99  | Electronics | 150       |
| Monitor       | $399.99 | Electronics | 75        |
| Headphones    | $199.99 | Electronics | 100       |
| Desk Chair    | $299.99 | Furniture   | 30        |
| Standing Desk | $499.99 | Furniture   | 20        |
| Notebook      | $9.99   | Stationery  | 500       |
| Pen Set       | $19.99  | Stationery  | 300       |
| Backpack      | $59.99  | Accessories | 120       |

---

## Monitoring

### Prometheus Metrics

Exposed at `/metrics`:

```
# Request metrics
product_service_requests_total{method="GET",endpoint="/api/products",status="200"} 42
product_service_request_duration_seconds_bucket{method="GET",endpoint="/api/products",le="0.1"} 38

# Cache metrics
product_service_cached_products 8

# Queue metrics (for KEDA autoscaling)
product_service_queue_depth 0
```

### Health Checks

**Liveness Probe** (`/healthz`):

- Checks if service is alive
- K8s restarts pod if this fails

**Readiness Probe** (`/ready`):

- Checks if service is ready for traffic
- Returns dependency status:
  - Database (required)
  - Cache (optional)
  - Queue (optional)

Example response:

```json
{
  "status": "ready",
  "service": "product-service",
  "timestamp": "2026-01-17T15:30:00Z",
  "dependencies": {
    "database": true,
    "cache": true,
    "queue": true
  }
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Client Request                     │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
                  ┌─────────────┐
                  │   FastAPI   │
                  │  (main.py)  │
                  └──────┬──────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   ┌─────────┐    ┌───────────┐    ┌──────────┐
   │  Cache  │    │ Database  │    │  Queue   │
   │ (Redis) │    │(Postgres) │    │(RabbitMQ)│
   └─────────┘    └───────────┘    └──────────┘
        │                │                │
        └────────────────┴────────────────┘
                         │
                         ▼
              Hit? Return cached data
              Miss? Query database → Cache → Return
```

**Request Flow:**

1. Client sends request to FastAPI
2. Check Redis cache for data
3. If cache hit → Return immediately
4. If cache miss → Query PostgreSQL
5. Store result in cache (5 min TTL)
6. Return to client

**Background Processing:**

- RabbitMQ consumer listens for inventory updates
- Updates database and invalidates cache
- Demonstrates KEDA event-driven autoscaling

---

## RabbitMQ Integration

### Queue Structure

**Exchange:** `events` (topic)

**Queue:** `inventory.updates`

**Routing Key:** `product.inventory.update`

### Send Test Message

```bash
# Using RabbitMQ Management UI
# Go to http://localhost:15672 → Queues → inventory.updates → Publish message

# Message format:
{
  "event": "product.inventory.update",
  "timestamp": "2026-01-17T15:30:00Z",
  "data": {
    "product_id": "your-product-id-here",
    "old_count": 50,
    "new_count": 45
  }
}
```

Watch the service logs to see it process the message!

---

## Troubleshooting

### Service won't start

**Issue: Port already in use**

```bash
# Find process using port 8081
netstat -ano | findstr :8081

# Kill the process (Windows)
taskkill /PID <PID> /F

# Or use different port
python -m uvicorn app.main:app --reload --port 8082
```

**Issue: Import errors or module not found**

```bash
# Make sure venv is activated (should see (venv) in prompt)
venv\Scripts\activate.bat

# Verify you're in the right directory
cd C:\path\to\product-service
dir app  # Should show app folder with Python files

# Reinstall dependencies
pip install -r requirements.txt
```

**Issue: Python version too new (3.13+)**

```bash
# Check Python version
python --version

# If 3.13+, use Python 3.11 or 3.12:
py -3.11 -m venv venv
# or
conda create -n product-service python=3.11
```

### Search endpoint returns UUID error

**Issue:** `/api/products/search` tries to parse "search" as UUID

**Solution:** Make sure search route is defined BEFORE the `{product_id}` route in `app/main.py`. The corrected file has this fixed.

Also, use the trailing slash:

```bash
# Correct
curl "http://localhost:8081/api/products/search/?q=laptop"

# Also works
curl "http://localhost:8081/api/products/search?q=laptop"
```

### Port already in use

```bash
# Find what's using port 8081
lsof -i :8081

# Kill the process
kill -9 <PID>

# Or use different port
python -m uvicorn app.main:app --port 8082
```

### No mock data appearing

```bash
# Delete and recreate database
docker-compose down -v
docker-compose up -d

# Data is auto-inserted on first startup
```

---

## Development

### Project Structure

```
product-service/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application & routes
│   ├── models.py            # Pydantic models
│   ├── config.py            # Configuration
│   ├── database.py          # PostgreSQL handler
│   ├── mock_database.py     # In-memory mock DB
│   ├── cache.py             # Redis cache handler
│   └── queue.py             # RabbitMQ consumer
├── Dockerfile               # Container image
├── docker-compose.yml       # Local development stack
├── requirements.txt         # Python dependencies
├── .dockerignore           # Docker ignore patterns
└── README.md               # This file
```

### Adding New Endpoints

Edit `app/main.py`:

```python
@app.get("/api/products/categories")
async def get_categories():
    """Get all product categories"""
    # Your logic here
    return {"categories": ["Electronics", "Furniture"]}
```

### Running Tests

```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests (to be implemented)
pytest
```

---

## Next Steps

- ✅ Product Service created
- ⏭️ Create User Service
- ⏭️ Create Frontend Service
- ⏭️ Create Kubernetes manifests
- ⏭️ Set up Istio service mesh
- ⏭️ Configure HPA & KEDA
- ⏭️ Set up observability (Prometheus, Grafana, Jaeger)

---

## Kubernetes Deployment

See the `k8s/` directory for Kubernetes manifests (coming next).

The service is designed for K8s with:

- ✅ Health checks (`/healthz`, `/ready`)
- ✅ Prometheus metrics (`/metrics`)
- ✅ Graceful shutdown
- ✅ ConfigMap/Secret support
- ✅ HPA ready (CPU-based scaling)
- ✅ KEDA ready (queue-based scaling)
- ✅ Service mesh ready (Istio/Linkerd)

---

## License

MIT - Feel free to use for learning!

## Questions?

This is a learning project to demonstrate K8s concepts. It's intentionally simple with mock data and minimal business logic. Perfect for understanding microservices architecture, autoscaling, service mesh, and observability!

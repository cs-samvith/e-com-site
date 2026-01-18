# Running Product Service with Full Stack

Complete guide to run the service with PostgreSQL, Redis, and RabbitMQ.

## Two Modes Supported

The service automatically detects and adapts:

### Mode 1: Mock Mode (Current - No Dependencies)

```
✅ In-memory mock database
⚠️ Redis disabled
⚠️ RabbitMQ disabled
```

### Mode 2: Full Stack (With Real Infrastructure)

```
✅ PostgreSQL database (persistent)
✅ Redis cache (performance)
✅ RabbitMQ queue (async processing)
```

---

## Quick Start - Full Stack

### Step 1: Start Infrastructure

```bash
# From project root (C:\mygit\e-com-site)
mkdir infrastructure
# Copy init-db.sql to infrastructure folder

# Start PostgreSQL, Redis, RabbitMQ
docker-compose -f docker-compose-infra.yml up -d

# Verify all services are running
docker-compose -f docker-compose-infra.yml ps

# Should show:
# local-postgres   running   5432/tcp
# local-redis      running   6379/tcp
# local-rabbitmq   running   5672/tcp, 15672/tcp
```

### Step 2: Configure Product Service

```bash
cd services/product-service

# Copy .env.local to .env
copy .env.local .env

# Or create .env manually with:
echo DB_HOST=localhost > .env
echo DB_PORT=5432 >> .env
echo DB_NAME=products_db >> .env
echo REDIS_HOST=localhost >> .env
echo RABBITMQ_HOST=localhost >> .env
echo MOCK_MODE=false >> .env
```

### Step 3: Run Product Service

```bash
# Make sure venv is activated
venv\Scripts\activate.bat

# Run service (will connect to real infrastructure)
python -m uvicorn app.main:app --reload --port 8081
```

**You should see:**

```
INFO: Attempting to connect to PostgreSQL at localhost:5432
INFO: ✓ Connected to PostgreSQL - using real database
INFO: Database initialized
INFO: Inserted 10 mock products
INFO: Redis connection established
INFO: Connected to RabbitMQ
INFO: product-service started successfully on port 8081
```

---

## Verify Real Infrastructure

### Check PostgreSQL

```bash
# Connect to database
docker exec -it local-postgres psql -U postgres -d products_db

# Inside psql:
\dt                           # List tables
SELECT COUNT(*) FROM products; # Should show 10
SELECT name, price FROM products LIMIT 5;
\q                            # Exit
```

### Check Redis

```bash
# Connect to Redis
docker exec -it local-redis redis-cli

# Inside redis-cli:
PING                    # Should return PONG
KEYS product:*         # Show cached products
GET product:{some-id}  # View cached data
exit
```

### Check RabbitMQ

Open browser:

```
http://localhost:15672
Username: guest
Password: guest
```

Navigate to **Queues** → Should see `inventory.updates` queue

---

## Test the Difference

### Test 1: Caching Behavior

**Without Redis (Mock Mode):**

```bash
# Every request hits database
curl http://localhost:8081/api/products/{id}  # Database query
curl http://localhost:8081/api/products/{id}  # Database query again
```

**With Redis (Full Stack):**

```bash
# First request
curl http://localhost:8081/api/products/{id}
# Logs: "Cache MISS for product {id}"
# Queries database, stores in cache

# Second request (within 5 minutes)
curl http://localhost:8081/api/products/{id}
# Logs: "Cache HIT for product {id}"
# Returns from cache (faster!)

# Check cache stats
curl http://localhost:8081/debug/cache-stats
# Shows: hits, misses, keys cached
```

### Test 2: Data Persistence

**Without PostgreSQL (Mock Mode):**

```bash
# Create product
curl -X POST http://localhost:8081/api/products -d {...}

# Restart service (Ctrl+C, then start again)
curl http://localhost:8081/api/products
# Product is GONE! (in-memory only)
```

**With PostgreSQL (Full Stack):**

```bash
# Create product
curl -X POST http://localhost:8081/api/products -d {...}

# Restart service
# Product still exists! (persisted to database)
```

### Test 3: Queue Processing

**With RabbitMQ (Full Stack):**

Publish a message to test KEDA scaling:

```bash
# 1. Open RabbitMQ UI: http://localhost:15672

# 2. Go to Queues → inventory.updates

# 3. Click "Publish message"

# 4. Paste this payload:
{
  "event": "product.inventory.update",
  "timestamp": "2026-01-18T12:00:00Z",
  "data": {
    "product_id": "paste-a-real-product-id-here",
    "old_count": 50,
    "new_count": 45
  }
}

# 5. Check service logs - you'll see:
# INFO: Received inventory update: ...
# INFO: Updated inventory for product {id}: 50 → 45
# INFO: Message processed and acknowledged
```

---

## Switching Between Modes

### Switch to Mock Mode (Fast Development)

```bash
# Option 1: Set environment variable
set MOCK_MODE=true
python -m uvicorn app.main:app --reload --port 8081

# Option 2: Delete .env file
del .env
python -m uvicorn app.main:app --reload --port 8081

# Option 3: Update .env
echo MOCK_MODE=true > .env
```

### Switch to Full Stack Mode

```bash
# Start infrastructure
docker-compose -f docker-compose-infra.yml up -d

# Use .env.local
copy .env.local .env

# Run service
python -m uvicorn app.main:app --reload --port 8081
```

---

## Complete Setup Commands

### One-Time Setup

```bash
# 1. Create project structure
C:\mygit\e-com-site\
├── infrastructure/
│   └── init-db.sql
├── docker-compose-infra.yml
└── services/
    ├── product-service/
    └── user-service/

# 2. Copy files from artifacts above

# 3. Start infrastructure
cd C:\mygit\e-com-site
docker-compose -f docker-compose-infra.yml up -d
```

### Daily Development Workflow

```bash
# Start infrastructure (if not running)
docker-compose -f docker-compose-infra.yml up -d

# Start Product Service
cd services\product-service
venv\Scripts\activate.bat
copy .env.local .env
python -m uvicorn app.main:app --reload --port 8081

# Start User Service (in new terminal)
cd services\user-service
venv\Scripts\activate.bat
copy .env.local .env
python -m uvicorn app.main:app --reload --port 8080

# Start Frontend (in new terminal)
cd services\frontend-service
npm run dev
```

### Stop Everything

```bash
# Stop infrastructure
docker-compose -f docker-compose-infra.yml down

# Stop services (Ctrl+C in each terminal)
```

---

## Environment Variable Reference

| Variable        | Mock Mode           | Full Stack  |
| --------------- | ------------------- | ----------- |
| `MOCK_MODE`     | `true` (or not set) | `false`     |
| `DB_HOST`       | `postgres-service`  | `localhost` |
| `REDIS_HOST`    | `redis-service`     | `localhost` |
| `RABBITMQ_HOST` | `rabbitmq-service`  | `localhost` |

---

## Monitoring Full Stack

### PostgreSQL

```bash
# View logs
docker logs local-postgres -f

# Access database
docker exec -it local-postgres psql -U postgres -d products_db
```

### Redis

```bash
# View logs
docker logs local-redis -f

# Monitor commands
docker exec -it local-redis redis-cli MONITOR
```

### RabbitMQ

```bash
# View logs
docker logs local-rabbitmq -f

# Management UI
http://localhost:15672 (guest/guest)
```

---

## Performance Comparison

### Response Times

**Mock Mode (No Cache):**

- First request: ~10ms
- Subsequent requests: ~10ms
- All requests hit in-memory database

**Full Stack (With Redis):**

- First request: ~50ms (PostgreSQL query + cache store)
- Cached requests: ~2ms (Redis cache hit)
- 25x faster for cached data!

### Data Persistence

**Mock Mode:**

- Create 100 products
- Restart service
- Products = 10 (back to default)

**Full Stack:**

- Create 100 products
- Restart service
- Products = 110 (10 default + 100 created)

---

## Troubleshooting Full Stack

### Can't connect to PostgreSQL

```bash
# Check if PostgreSQL is running
docker ps | findstr postgres

# Check logs
docker logs local-postgres

# Test connection
docker exec local-postgres psql -U postgres -c "SELECT 1"
```

### Can't connect to Redis

```bash
# Check if Redis is running
docker ps | findstr redis

# Test connection
docker exec local-redis redis-cli ping
# Should return: PONG
```

### Service still using mock database

```bash
# Check .env file exists
type .env

# Verify DB_HOST=localhost (not postgres-service)
# Verify MOCK_MODE=false

# Check service logs for:
# "✓ Connected to PostgreSQL - using real database"
```

---

## Quick Reference Commands

```bash
# Start infrastructure only
docker-compose -f docker-compose-infra.yml up -d

# Stop infrastructure
docker-compose -f docker-compose-infra.yml down

# Clean everything (including data)
docker-compose -f docker-compose-infra.yml down -v

# View all logs
docker-compose -f docker-compose-infra.yml logs -f

# Restart a service
docker-compose -f docker-compose-infra.yml restart postgres
```

---

## Summary: What Code Handles

The existing code **already handles both cases** automatically:

✅ **PostgreSQL**: Tries to connect → Falls back to mock if unavailable  
✅ **Redis**: Tries to connect → Disables caching if unavailable  
✅ **RabbitMQ**: Tries to connect → Disables queue if unavailable

**No code changes needed!** Just change environment variables to switch modes.

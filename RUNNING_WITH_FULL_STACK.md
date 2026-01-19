# Running with Full Stack Infrastructure

This guide explains how to run the microservices with **real infrastructure** (PostgreSQL, Redis, RabbitMQ) or in **mock mode** (no dependencies).

---

## 🎯 Quick Start

### Option 1: Mock Mode (No Dependencies)

Perfect for development and testing without Docker.

```bash
# Product Service
cd services/product-service
run-mock.bat

# User Service
cd services/user-service
run-mock.bat
```

### Option 2: Real Infrastructure Mode

Run with actual PostgreSQL, Redis, and RabbitMQ.

```bash
# 1. Start Infrastructure (one time)
docker-compose -f docker-compose-infra.yml up -d

# 2. Product Service
cd services/product-service
run-with-stack.bat

# 3. User Service
cd services/user-service
run-with-stack.bat
```

---

## 📋 Prerequisites

### For Mock Mode

- Python 3.11+
- Virtual environment (automatically created by scripts)

### For Real Infrastructure Mode

- Docker Desktop **OR** Podman installed and running
- Ports available: 5432 (PostgreSQL), 6379 (Redis), 5672/15672 (RabbitMQ)

---

## 🏗️ Infrastructure Setup

### Option A: Using Docker Compose (Recommended)

```bash
# From project root
docker-compose -f docker-compose-infra.yml up -d
```

### Option B: Using Podman on Windows

If you're using Podman instead of Docker:

```bash
# Start PostgreSQL
podman run -d --name local-postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15

# Start Redis
podman run -d --name local-redis -p 6379:6379 redis:7-alpine

# Start RabbitMQ
podman run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

Both options start:

- **PostgreSQL** on `localhost:5432`
- **Redis** on `localhost:6379`
- **RabbitMQ** on `localhost:5672` (Management UI: http://localhost:15672)

### Verify Infrastructure

**For Docker Compose:**

```bash
# Check all services are running
docker-compose -f docker-compose-infra.yml ps

# Check logs
docker-compose -f docker-compose-infra.yml logs -f

# Test connections
docker exec local-postgres psql -U postgres -c "SELECT 1"
docker exec local-redis redis-cli ping
```

**For Podman:**

```bash
# Check all services are running
podman ps

# Test connections
podman exec local-postgres psql -U postgres -c "SELECT 1"
podman exec local-redis redis-cli ping
podman exec rabbitmq rabbitmqctl status
```

### Stop Infrastructure

**For Docker Compose:**

```bash
# Stop but keep data
docker-compose -f docker-compose-infra.yml down

# Stop and remove all data (fresh start)
docker-compose -f docker-compose-infra.yml down -v
```

**For Podman:**

```bash
# Stop containers
podman stop local-postgres local-redis rabbitmq

# Remove containers (keeps data in volumes)
podman rm local-postgres local-redis rabbitmq

# Remove containers and volumes (fresh start)
podman rm -v local-postgres local-redis rabbitmq
```

---

## 🚀 Running Each Service

### Product Service

**Port:** 8081  
**Database:** `products_db`

#### Mock Mode

```bash
cd services/product-service
run-mock.bat

# Or manually:
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
set MOCK_MODE=true
python -m uvicorn app.main:app --reload --port 8081
```

#### Real Infrastructure Mode

```bash
cd services/product-service
run-with-stack.bat

# Or manually:
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.local .env
python -m uvicorn app.main:app --reload --port 8081
```

**Test:**

```bash
curl http://localhost:8081/health
curl http://localhost:8081/api/products
```

---

### User Service

**Port:** 8080  
**Database:** `users_db`

#### Mock Mode

```bash
cd services/user-service
run-mock.bat

# Or manually:
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
set MOCK_MODE=true
python -m uvicorn app.main:app --reload --port 8080
```

#### Real Infrastructure Mode

```bash
cd services/user-service
run-with-stack.bat

# Or manually:
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.local .env
python -m uvicorn app.main:app --reload --port 8080
```

**Test:**

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/users
```

---

## 🔄 Mode Comparison

### Mock Mode Features

✅ No external dependencies  
✅ Fast startup  
✅ Perfect for development  
✅ In-memory data (resets on restart)  
❌ No caching (Redis)  
❌ No message queue (RabbitMQ)  
❌ Data not persisted

### Real Infrastructure Mode Features

✅ Real PostgreSQL database  
✅ Redis caching enabled  
✅ RabbitMQ message queue  
✅ Data persists across restarts  
✅ Full production-like environment  
❌ Requires Docker  
❌ Slower startup

---

## 📊 Monitoring & Management

### PostgreSQL (localhost:5432)

```bash
# Connect to database (Docker)
docker exec -it local-postgres psql -U postgres

# OR Connect to database (Podman)
podman exec -it local-postgres psql -U postgres

# Inside psql:
\l                          # List databases
\c products_db             # Connect to products database
\dt                        # List tables
SELECT * FROM products;    # Query data

\c users_db                # Connect to users database
\dt                        # List tables
SELECT * FROM users;       # Query data
```

### Redis (localhost:6379)

```bash
# Connect to Redis (Docker)
docker exec -it local-redis redis-cli

# OR Connect to Redis (Podman)
podman exec -it local-redis redis-cli

# Inside redis-cli:
KEYS *                     # List all keys
GET products:1            # Get specific key
GET users:1               # Get specific user
FLUSHALL                  # Clear all cache
```

### RabbitMQ (localhost:15672)

Open in browser: http://localhost:15672

- **Username:** guest
- **Password:** guest

Monitor:

- Queues and messages
- Connections
- Channels
- Exchanges

---

## 🧪 Testing Scenarios

### Data Persistence Test

**Mock Mode:**

```bash
# Create a product
curl -X POST http://localhost:8081/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Test","price":99.99,"category":"Test","inventory_count":100}'

# Restart service (Ctrl+C, then run-mock.bat)

# Check products - Test product is GONE
curl http://localhost:8081/api/products
```

**Real Mode:**

```bash
# Create a product
curl -X POST http://localhost:8081/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Test","price":99.99,"category":"Test","inventory_count":100}'

# Restart service (Ctrl+C, then run-with-stack.bat)

# Check products - Test product STILL EXISTS
curl http://localhost:8081/api/products
```

### Cache Performance Test

**Only works in Real Infrastructure Mode**

```bash
# First request (cache miss)
curl http://localhost:8081/api/products/1

# Second request (cache hit - much faster)
curl http://localhost:8081/api/products/1

# Check cache stats
curl http://localhost:8081/debug/cache-stats
```

### Message Queue Test

**Only works in Real Infrastructure Mode**

1. Open RabbitMQ UI: http://localhost:15672
2. Navigate to Queues → `inventory.updates`
3. Publish a message:

```json
{
  "product_id": 1,
  "inventory_count": 999
}
```

4. Watch service logs process the message
5. Verify product inventory updated:

```bash
curl http://localhost:8081/api/products/1
```

### Inter-Service Communication Test

**Test both services working together:**

```bash
# Create a user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'

# Get products
curl http://localhost:8081/api/products

# Both services can access shared infrastructure
# Check Redis for cached data from both services
docker exec -it local-redis redis-cli
KEYS *
```

---

## 🔧 Troubleshooting

### Services Won't Start

**Check if infrastructure is running:**

```bash
# Docker Compose
docker ps

# OR Podman
podman ps
```

**Check service logs:**

```bash
# Docker Compose
docker-compose -f docker-compose-infra.yml logs -f

# OR Podman
podman logs local-postgres
podman logs local-redis
podman logs rabbitmq

# Product/User service logs (look at terminal output)
```

### PostgreSQL Connection Errors

```bash
# Docker
docker ps | findstr postgres
docker logs local-postgres
docker exec local-postgres psql -U postgres -c "SELECT 1"
docker-compose -f docker-compose-infra.yml restart postgres

# OR Podman
podman ps | findstr postgres
podman logs local-postgres
podman exec local-postgres psql -U postgres -c "SELECT 1"
podman restart local-postgres
```

### Redis Connection Errors

```bash
# Docker
docker ps | findstr redis
docker exec local-redis redis-cli ping
docker-compose -f docker-compose-infra.yml restart redis

# OR Podman
podman ps | findstr redis
podman exec local-redis redis-cli ping
podman restart local-redis
```

### RabbitMQ Connection Errors

```bash
# Docker
docker ps | findstr rabbitmq
docker logs local-rabbitmq
docker-compose -f docker-compose-infra.yml restart rabbitmq

# OR Podman
podman ps | findstr rabbitmq
podman logs rabbitmq
podman restart rabbitmq
```

### Port Already in Use

```bash
# Find what's using the port
netstat -ano | findstr :8081
netstat -ano | findstr :8080
netstat -ano | findstr :5432

# Kill the process (use PID from above)
taskkill /PID <PID> /F
```

### Service Using Mock Despite .env File

```bash
# Verify .env file exists
type services\product-service\.env

# Check MOCK_MODE=false in .env

# Verify DB_HOST=localhost (not postgres-service)

# Check service startup logs for:
# "✓ Connected to PostgreSQL - using real database"
```

---

## 📁 File Structure

```
e-com-site/
├── docker-compose-infra.yml          # Infrastructure services
├── RUNNING_WITH_FULL_STACK.md        # This file
│
├── infrastructure/
│   └── init-db.sql                   # Database initialization
│
└── services/
    ├── product-service/              # Port 8081
    │   ├── .env.local               # Real infra config template
    │   ├── .env                     # Active config (git ignored)
    │   ├── run-mock.bat            # Start in mock mode
    │   └── run-with-stack.bat      # Start with real infra
    │
    └── user-service/                 # Port 8080
        ├── .env.local
        ├── run-mock.bat
        └── run-with-stack.bat
```

---

## 🎯 Recommended Workflow

### Phase 1: Development (Mock Mode)

- Fast iterations
- No Docker overhead
- Test API logic
- Develop new features

### Phase 2: Integration Testing (Real Infrastructure)

- Test data persistence
- Test caching behavior
- Test message queuing
- Performance testing
- Inter-service communication

### Phase 3: Production Simulation

- Run both services together
- Test end-to-end flows
- Load testing
- Observability testing

---

## 🚀 Quick Reference

### Start Everything (Real Infrastructure)

```bash
# Terminal 1 - Infrastructure
docker-compose -f docker-compose-infra.yml up -d

# Terminal 2 - Product Service
cd services/product-service && run-with-stack.bat

# Terminal 3 - User Service
cd services/user-service && run-with-stack.bat
```

### Start Everything (Mock Mode)

```bash
# Terminal 1 - Product Service
cd services/product-service && run-mock.bat

# Terminal 2 - User Service
cd services/user-service && run-mock.bat
```

### Stop Everything

```bash
# Stop services (Ctrl+C in each terminal)

# Stop infrastructure
docker-compose -f docker-compose-infra.yml down

# Clean up data (optional)
docker-compose -f docker-compose-infra.yml down -v
```

---

## 📚 Additional Resources

- **Product Service README:** `services/product-service/README.md`
- **User Service README:** `services/user-service/README.md`
- **API Documentation:**
  - Product: http://localhost:8081/docs
  - User: http://localhost:8080/docs

---

## ✅ Summary

**Current Status:**

- ✅ Product Service - Fully configured for both modes
- ✅ User Service - Ready to configure
- ✅ Infrastructure - Docker Compose ready
- ✅ Mock Mode - Works without dependencies
- ✅ Real Mode - Full production-like stack

**To Switch Modes:**

- **Mock:** Run `run-mock.bat`
- **Real:** Run `run-with-stack.bat`

You now have a complete microservices environment that works in both development (mock) and production-like (real infrastructure) modes! 🎉

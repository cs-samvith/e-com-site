# Docker Compose Guide

## Two Compose Files - When to Use What

### docker-compose-infra.yml (Infrastructure Only) 🔧

**Use for:** Development - run services locally in Python

```batch
REM Start infrastructure
docker-compose -f docker-compose-infra.yml up -d

REM Run services locally
cd services\product-service
venv\Scripts\activate.bat
set DB_HOST=localhost
python -m uvicorn app.main:app --reload --port 8081
```

**What it starts:**

- PostgreSQL (port 5432)
- Redis (port 6379)
- RabbitMQ (ports 5672, 15672)

**Containers:**

- `local-postgres`
- `local-redis`
- `local-rabbitmq`

---

### docker-compose.yml (Full Stack) 🚀

**Use for:** Testing - run everything in Docker

```batch
REM Start everything
docker-compose up -d

REM Services run in containers
```

**What it starts:**

- PostgreSQL (port 5432)
- Redis (port 6379)
- RabbitMQ (ports 5672, 15672)
- Product Service (port 8081) - containerized
- User Service (port 8080) - containerized (when uncommented)

**Containers:**

- `postgres-local`
- `redis-local`
- `rabbitmq-local`
- `product-service`
- `user-service`

---

## Quick Commands

### Infrastructure Only (Development)

```batch
# Start
docker-compose -f docker-compose-infra.yml up -d

# Check status
docker-compose -f docker-compose-infra.yml ps

# View logs
docker-compose -f docker-compose-infra.yml logs -f

# Stop
docker-compose -f docker-compose-infra.yml down

# Stop and remove data
docker-compose -f docker-compose-infra.yml down -v
```

### Full Stack (All Services)

```batch
# Start
docker-compose up -d

# Start specific services
docker-compose up -d postgres redis rabbitmq
docker-compose up -d product-service

# View logs
docker-compose logs -f product-service

# Stop
docker-compose down

# Rebuild and restart
docker-compose up -d --build product-service
```

---

## Typical Workflows

### Daily Development

```batch
REM Start infrastructure once (keeps running)
docker-compose -f docker-compose-infra.yml up -d

REM Run Product Service locally (Terminal 1)
cd services\product-service
run-with-stack.bat

REM Run User Service locally (Terminal 2)
cd services\user-service
run-with-stack.bat

REM Make code changes → auto-reloads
```

### Testing Containerized Deployment

```batch
REM Build and start everything
docker-compose up -d --build

REM Test
curl http://localhost:8081/api/products
curl http://localhost:8080/healthz

REM View logs
docker-compose logs -f
```

---

## Container Name Differences

| File            | PostgreSQL       | Redis         | RabbitMQ         | Services                          |
| --------------- | ---------------- | ------------- | ---------------- | --------------------------------- |
| **infra.yml**   | `local-postgres` | `local-redis` | `local-rabbitmq` | None                              |
| **compose.yml** | `postgres-local` | `redis-local` | `rabbitmq-local` | `product-service`, `user-service` |

⚠️ **Don't run both at the same time!** Container names conflict.

---

## Which Should You Use?

### Use docker-compose-infra.yml when:

- ✅ Developing and testing code changes
- ✅ Debugging with breakpoints
- ✅ Want fast reloads
- ✅ Need to see logs directly

### Use docker-compose.yml when:

- ✅ Testing Docker builds
- ✅ Testing multi-service integration
- ✅ Simulating production environment
- ✅ Running all services together

---

## My Recommendation

**For learning and development:** Use `docker-compose-infra.yml`

```batch
REM Keep this running all the time
docker-compose -f docker-compose-infra.yml up -d

REM Run services locally (fast development)
cd services\product-service
run-with-stack.bat
```

**For testing deployment:** Use `docker-compose.yml`

```batch
REM Test containerized deployment
docker-compose up -d --build
```

---

## Update Helper Scripts

Your `run-with-stack.bat` should use the infra file:

```batch
docker-compose -f docker-compose-infra.yml up -d
```

Or just:

```batch
docker-compose up -d postgres redis rabbitmq
```

Both work! The second one is simpler.

---

**Keep both files!** They serve different purposes. Just make sure you understand when to use each one. 🎯

Ready to set up **User Service** now? 🚀

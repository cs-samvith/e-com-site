# Getting Started with Product Service

## 🚀 Quick Start (3 Options)

### Option 1: Instant Start (No Setup Required!)

```bash
# Install minimal dependencies
pip install fastapi uvicorn pydantic pydantic-settings prometheus-client python-json-logger

# Run immediately
python -m uvicorn app.main:app --reload --port 8081

# Test it
curl http://localhost:8081/api/products
```

✅ **Works immediately**  
✅ **No database setup**  
✅ **10 mock products ready**  
⚠️ Data lost on restart

---

### Option 2: Full Stack (Recommended)

```bash
# Start everything with one command
docker-compose up -d

# Service is ready!
curl http://localhost:8081/api/products

# View logs
docker-compose logs -f product-service

# Stop everything
docker-compose down
```

✅ **PostgreSQL (persistent data)**  
✅ **Redis (caching)**  
✅ **RabbitMQ (messaging)**  
✅ **All features enabled**

---

### Option 3: Interactive Menu

```bash
# Make script executable
chmod +x quickstart.sh

# Run interactive menu
./quickstart.sh
```

Choose your preferred option from the menu!

---

## 🧪 Test the Service

```bash
# Install test dependencies
pip install requests

# Run test suite
python test_service.py
```

This will test:

- ✓ Health checks
- ✓ All CRUD operations
- ✓ Search functionality
- ✓ Caching
- ✓ Metrics endpoint

---

## 📚 API Examples

### Get All Products

```bash
curl http://localhost:8081/api/products
```

### Get Single Product

```bash
# Get product ID from above, then:
curl http://localhost:8081/api/products/{product_id}
```

### Create Product

```bash
curl -X POST http://localhost:8081/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Gaming Mouse",
    "description": "RGB gaming mouse",
    "price": 79.99,
    "category": "Electronics",
    "inventory_count": 50
  }'
```

### Search Products

```bash
curl "http://localhost:8081/api/products/search?q=laptop"
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

## 🐳 Docker Commands

### Start Full Stack

```bash
docker-compose up -d
```

### View Logs

```bash
# All services
docker-compose logs -f

# Product service only
docker-compose logs -f product-service

# PostgreSQL
docker-compose logs -f postgres
```

### Check Service Status

```bash
docker-compose ps
```

### Restart Service

```bash
docker-compose restart product-service
```

### Stop Everything

```bash
docker-compose down
```

### Clean Slate (Remove Data)

```bash
docker-compose down -v
```

### Rebuild and Start

```bash
docker-compose up -d --build
```

---

## 🔍 Access Services

When using Docker Compose:

| Service             | URL                    | Credentials       |
| ------------------- | ---------------------- | ----------------- |
| Product API         | http://localhost:8081  | -                 |
| RabbitMQ Management | http://localhost:15672 | guest/guest       |
| PostgreSQL          | localhost:5432         | postgres/postgres |
| Redis               | localhost:6379         | -                 |

---

## 🛠️ Development Workflow

### 1. Start Dependencies Only

```bash
# Start just PostgreSQL and Redis
docker run -d --name postgres-local \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=products_db \
  -p 5432:5432 postgres:15

docker run -d --name redis-local \
  -p 6379:6379 redis:7-alpine
```

### 2. Run Service Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment
export DB_HOST=localhost
export REDIS_HOST=localhost

# Run with auto-reload
python -m uvicorn app.main:app --reload --port 8081
```

### 3. Make Changes

Edit files in `app/` directory - service auto-reloads!

---

## 📊 Monitoring

### Check Health

```bash
# Liveness (is service alive?)
curl http://localhost:8081/healthz

# Readiness (ready for traffic?)
curl http://localhost:8081/ready
```

### View Metrics

```bash
curl http://localhost:8081/metrics
```

### Cache Statistics

```bash
curl http://localhost:8081/debug/cache-stats
```

---

## 🐛 Troubleshooting

### Service Won't Start

**Check if port is in use:**

```bash
lsof -i :8081
# If something is using it:
kill -9 <PID>
```

**Check dependencies:**

```bash
# PostgreSQL
docker exec postgres-local psql -U postgres -c "SELECT 1"

# Redis
docker exec redis-local redis-cli ping

# RabbitMQ
docker exec rabbitmq-local rabbitmq-diagnostics ping
```

### No Mock Data

```bash
# Recreate database
docker-compose down -v
docker-compose up -d
```

### Import Errors

```bash
# Reinstall dependencies
pip install -r requirements.txt
```

### Database Connection Failed

Just run without PostgreSQL! Service automatically uses in-memory mock database:

```bash
python -m uvicorn app.main:app --port 8081
```

---

## 📁 Project Structure

```
product-service/
├── app/
│   ├── main.py           # FastAPI app & routes
│   ├── models.py         # Data models
│   ├── database.py       # PostgreSQL handler
│   ├── mock_database.py  # In-memory mock
│   ├── cache.py          # Redis cache
│   ├── queue.py          # RabbitMQ consumer
│   └── config.py         # Configuration
├── docker-compose.yml    # Local dev stack
├── Dockerfile           # Container image
├── requirements.txt     # Python dependencies
├── test_service.py      # Test suite
├── quickstart.sh        # Interactive menu
└── README.md           # Full documentation
```

---

## ✅ Verification Checklist

After starting the service, verify:

- [ ] Service responds: `curl http://localhost:8081/healthz`
- [ ] Can get products: `curl http://localhost:8081/api/products`
- [ ] Can create product: `curl -X POST ...`
- [ ] Can search: `curl http://localhost:8081/api/products/search?q=laptop`
- [ ] Metrics work: `curl http://localhost:8081/metrics`

Run the test suite to verify everything:

```bash
python test_service.py
```

---

## 🎯 Next Steps

1. ✅ **Product Service** - You are here!
2. ⏭️ **User Service** - Authentication & user management
3. ⏭️ **Frontend Service** - Web UI
4. ⏭️ **Kubernetes Manifests** - Deploy to K8s
5. ⏭️ **Service Mesh** - Istio for mTLS
6. ⏭️ **Autoscaling** - HPA & KEDA
7. ⏭️ **Observability** - Prometheus, Grafana, Jaeger

---

## 💡 Tips

- **Development**: Use `--reload` flag for auto-restart on code changes
- **Testing**: Use standalone mode for fastest iteration
- **Production-like**: Use Docker Compose for full stack testing
- **Debugging**: Check logs with `docker-compose logs -f product-service`
- **Performance**: Redis caching improves response time by ~10x

---

## 🆘 Need Help?

1. Check service logs: `docker-compose logs product-service`
2. Test individual endpoints: `curl -v http://localhost:8081/api/products`
3. Verify dependencies: See troubleshooting section above
4. Start fresh: `docker-compose down -v && docker-compose up -d`

---

## 🎉 Success!

If you can run these commands successfully, you're ready to go:

```bash
# Health check
curl http://localhost:8081/healthz
# Should return: {"status":"healthy",...}

# Get products
curl http://localhost:8081/api/products
# Should return: Array of 10 products

# Metrics
curl http://localhost:8081/metrics
# Should return: Prometheus metrics
```

You're all set! 🚀

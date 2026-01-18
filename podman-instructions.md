# Running with Podman (Instead of Docker)

Podman is a Docker-compatible container engine that works without a daemon. All our Docker Compose files work with Podman!

## Setup Podman for Docker Compose

### Step 1: Verify Podman Installation

```powershell
# Check Podman version
podman --version

# Should show: podman version 4.x.x or higher
```

### Step 2: Start Podman Machine (Windows)

```powershell
# Initialize Podman machine (one-time setup)
podman machine init

# Start Podman machine
podman machine start

# Verify it's running
podman machine list

# Should show:
# NAME                     VM TYPE     CREATED      LAST UP            CPUS        MEMORY      DISK SIZE
# podman-machine-default*  wsl         2 hours ago  Currently running  2           2GiB        100GiB
```

### Step 3: Enable Docker Compatibility

```powershell
# Create Docker socket alias (run in PowerShell as Admin)
podman system service --time=0 tcp://localhost:2375

# Or simpler: Use podman-compose instead of docker-compose
```

---

## Option 1: Use podman-compose (Recommended)

Install and use podman-compose (drop-in replacement for docker-compose):

### Install podman-compose

```powershell
# Using pip
pip install podman-compose

# Verify installation
podman-compose --version
```

### Usage (Same as docker-compose!)

```batch
# Replace "docker-compose" with "podman-compose"

# Start infrastructure
podman-compose -f docker-compose-infra.yml up -d

# Start all services
podman-compose up -d

# View logs
podman-compose logs -f product-service

# Stop
podman-compose down

# Stop and remove volumes
podman-compose down -v
```

**That's it!** All your existing compose files work as-is.

---

## Option 2: Use Podman Directly (No Compose)

Run containers manually with podman:

### Start PostgreSQL

```powershell
podman run -d `
  --name postgres-local `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=postgres `
  -p 5432:5432 `
  -v postgres_data:/var/lib/postgresql/data `
  postgres:15
```

### Start Redis

```powershell
podman run -d `
  --name redis-local `
  -p 6379:6379 `
  -v redis_data:/data `
  redis:7-alpine redis-server --appendonly yes
```

### Start RabbitMQ

```powershell
podman run -d `
  --name rabbitmq-local `
  -e RABBITMQ_DEFAULT_USER=guest `
  -e RABBITMQ_DEFAULT_PASS=guest `
  -p 5672:5672 `
  -p 15672:15672 `
  -v rabbitmq_data:/var/lib/rabbitmq `
  rabbitmq:3-management
```

### Run Services Locally

```batch
# Now run your Python services locally
cd services\product-service
venv\Scripts\activate.bat
set DB_HOST=localhost
set REDIS_HOST=localhost
set RABBITMQ_HOST=localhost
python -m uvicorn app.main:app --reload --port 8081
```

---

## Option 3: Create Podman Pod (Podman's Native Way)

Podman has "pods" similar to Kubernetes pods:

### Create and Run Everything in a Pod

```powershell
# Create a pod
podman pod create --name microservices-pod -p 5432:5432 -p 6379:6379 -p 5672:5672 -p 15672:15672 -p 8081:8081

# Add PostgreSQL to pod
podman run -d --pod microservices-pod `
  --name postgres `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  postgres:15

# Add Redis to pod
podman run -d --pod microservices-pod `
  --name redis `
  redis:7-alpine

# Add RabbitMQ to pod
podman run -d --pod microservices-pod `
  --name rabbitmq `
  -e RABBITMQ_DEFAULT_USER=guest `
  -e RABBITMQ_DEFAULT_PASS=guest `
  rabbitmq:3-management

# All services can communicate within the pod!
```

---

## Podman vs Docker Commands

All Docker commands work with Podman by just replacing `docker` with `podman`:

| Docker Command      | Podman Equivalent   |
| ------------------- | ------------------- |
| `docker ps`         | `podman ps`         |
| `docker images`     | `podman images`     |
| `docker run`        | `podman run`        |
| `docker build`      | `podman build`      |
| `docker-compose up` | `podman-compose up` |
| `docker logs`       | `podman logs`       |
| `docker exec`       | `podman exec`       |
| `docker stop`       | `podman stop`       |
| `docker rm`         | `podman rm`         |

---

## Updated Helper Scripts for Podman

### run-with-stack-podman.bat

```batch
@echo off
echo Starting infrastructure with Podman...
echo.

cd ..\..

REM Use podman-compose instead of docker-compose
podman-compose -f docker-compose-infra.yml up -d

echo.
echo Infrastructure started!
echo.
echo Starting Product Service locally...
cd services\product-service

set DB_HOST=localhost
set REDIS_HOST=localhost
set RABBITMQ_HOST=localhost
set MOCK_MODE=false

call venv\Scripts\activate.bat
python -m uvicorn app.main:app --reload --port 8081
```

### run-infra-podman.bat

```batch
@echo off
echo Starting Infrastructure with Podman...
echo.

podman-compose -f docker-compose-infra.yml up -d

echo.
echo Infrastructure started!
echo.
echo Services:
echo   PostgreSQL: localhost:5432
echo   Redis:      localhost:6379
echo   RabbitMQ:   localhost:5672
echo   RabbitMQ UI: http://localhost:15672 (guest/guest)
echo.
pause
```

---

## Verification Commands

### Check Podman Services

```powershell
# List running containers
podman ps

# List all containers
podman ps -a

# Check container logs
podman logs postgres-local

# Execute command in container
podman exec -it postgres-local psql -U postgres

# Check volumes
podman volume ls

# Check networks
podman network ls

# Inspect container
podman inspect postgres-local
```

---

## Podman-Specific Features

### Rootless Containers (Security Benefit!)

Podman runs containers without root privileges:

```powershell
# Containers run as your user (more secure)
podman run -d --name test redis:7-alpine

# No daemon required
# No background service running
```

### Generate Kubernetes YAML

Podman can generate K8s manifests from running containers:

```powershell
# Generate Kubernetes YAML
podman generate kube postgres-local > postgres-deployment.yaml

# Deploy to K8s
kubectl apply -f postgres-deployment.yaml
```

This is **perfect for learning K8s!** You can test locally with Podman, generate K8s YAML, and deploy.

---

## Troubleshooting Podman

### Issue 1: "podman-compose: command not found"

```powershell
# Install podman-compose
pip install podman-compose

# Verify
podman-compose --version
```

### Issue 2: Podman machine not started

```powershell
# Check machine status
podman machine list

# Start machine
podman machine start

# If no machine exists, create one
podman machine init
podman machine start
```

### Issue 3: Port conflicts

```powershell
# Check what's using the port
netstat -ano | findstr :5432

# Stop conflicting container
podman stop postgres-local
podman rm postgres-local
```

### Issue 4: Volume permissions

```powershell
# Podman volumes are in different location
podman volume ls

# Inspect volume
podman volume inspect postgres_data

# Remove volume (clean slate)
podman volume rm postgres_data
```

---

## Docker vs Podman Architecture

### Docker

```
Your Command → Docker CLI → Docker Daemon → Container
                               (runs as root)
```

### Podman

```
Your Command → Podman CLI → Container
                            (runs as your user, no daemon)
```

**Benefits of Podman:**

- ✅ No background daemon
- ✅ Rootless (more secure)
- ✅ Docker-compatible
- ✅ Can generate Kubernetes YAML
- ✅ Works with Docker Compose files

---

## Complete Setup with Podman

```powershell
# 1. Verify Podman is running
podman machine list

# 2. Install podman-compose
pip install podman-compose

# 3. Navigate to project
cd C:\mygit\e-com-site

# 4. Start infrastructure
podman-compose -f docker-compose-infra.yml up -d

# 5. Verify services are running
podman ps

# 6. Run Product Service
cd services\product-service
venv\Scripts\activate.bat
set DB_HOST=localhost
set REDIS_HOST=localhost
set RABBITMQ_HOST=localhost
set MOCK_MODE=false
python -m uvicorn app.main:app --reload --port 8081

# 7. Test
curl http://localhost:8081/api/products
```

---

## Accessing Services

Same as Docker:

```powershell
# PostgreSQL
podman exec -it local-postgres psql -U postgres -d products_db

# Redis
podman exec -it local-redis redis-cli

# RabbitMQ UI
start http://localhost:15672
# Login: guest/guest
```

---

## Cleanup Commands

```powershell
# Stop all containers
podman-compose -f docker-compose-infra.yml down

# Stop and remove volumes (clean slate)
podman-compose -f docker-compose-infra.yml down -v

# Remove all containers
podman rm -f $(podman ps -aq)

# Remove all volumes
podman volume prune -f

# Remove all images (free space)
podman image prune -a -f
```

---

## Advantages of Using Podman for This Project

1. **No Docker Desktop license required** - Free for all use cases
2. **More secure** - Rootless containers
3. **Kubernetes-ready** - Can generate K8s YAML from containers
4. **Docker-compatible** - All our compose files work
5. **Lighter weight** - No background daemon

---

## TL;DR - Quick Start with Podman

```powershell
# Install podman-compose
pip install podman-compose

# Start Podman machine
podman machine start

# Use podman-compose exactly like docker-compose
podman-compose -f docker-compose-infra.yml up -d

# Run services locally
cd services\product-service
run-with-stack.bat  # Just set DB_HOST=localhost

# Everything works the same!
```

---

## Next Steps

You can use Podman for:

1. ✅ Running infrastructure locally (PostgreSQL, Redis, RabbitMQ)
2. ✅ Building container images
3. ✅ Testing containerized services
4. ✅ Generating Kubernetes manifests
5. ✅ Learning container orchestration

**Podman is perfect for learning Kubernetes!** Since it can generate K8s YAML from running containers, you can test locally, then deploy to real K8s.

Ready to continue? 🚀

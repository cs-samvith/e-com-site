@echo off
REM Start infrastructure with Podman (no compose needed)
REM Run from: C:\mygit\e-com-site

echo ========================================
echo Starting Infrastructure with Podman
echo ========================================
echo.

REM Create network
echo [1/4] Creating network...
podman network create microservices 2>nul
if errorlevel 1 (
    echo   Network already exists
) else (
    echo   Created network: microservices
)
echo.

REM Start PostgreSQL
echo [2/4] Starting PostgreSQL...
podman run -d ^
  --name postgres-local ^
  --network microservices ^
  -e POSTGRES_USER=postgres ^
  -e POSTGRES_PASSWORD=postgres ^
  -p 5432:5432 ^
  -v postgres_data:/var/lib/postgresql/data ^
  postgres:15

if errorlevel 1 (
    echo   PostgreSQL already running or failed to start
    podman start postgres-local 2>nul
) else (
    echo   PostgreSQL started
)
echo.

REM Start Redis
echo [3/4] Starting Redis...
podman run -d ^
  --name redis-local ^
  --network microservices ^
  -p 6379:6379 ^
  -v redis_data:/data ^
  redis:7-alpine redis-server --appendonly yes

if errorlevel 1 (
    echo   Redis already running or failed to start
    podman start redis-local 2>nul
) else (
    echo   Redis started
)
echo.

REM Start RabbitMQ
echo [4/4] Starting RabbitMQ...
podman run -d ^
  --name rabbitmq-local ^
  --network microservices ^
  -e RABBITMQ_DEFAULT_USER=guest ^
  -e RABBITMQ_DEFAULT_PASS=guest ^
  -p 5672:5672 ^
  -p 15672:15672 ^
  -v rabbitmq_data:/var/lib/rabbitmq ^
  rabbitmq:3-management

if errorlevel 1 (
    echo   RabbitMQ already running or failed to start
    podman start rabbitmq-local 2>nul
) else (
    echo   RabbitMQ started
)
echo.

echo ========================================
echo Infrastructure Started!
echo ========================================
echo.
echo Services available:
echo   PostgreSQL: localhost:5432
echo   Redis:      localhost:6379
echo   RabbitMQ:   localhost:5672
echo   RabbitMQ UI: http://localhost:15672 (guest/guest)
echo.
echo To stop all:
echo   podman stop postgres-local redis-local rabbitmq-local
echo.
echo To remove all:
echo   podman rm -f postgres-local redis-local rabbitmq-local
echo.
pause
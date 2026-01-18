@echo off
REM Run Product Service with Full Stack (PostgreSQL + Redis + RabbitMQ)

echo ========================================
echo Product Service - Full Stack Mode
echo ========================================
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

echo [1/4] Starting infrastructure (PostgreSQL, Redis, RabbitMQ)...
cd ..\..
docker-compose -f docker-compose-infra.yml up -d

echo.
echo [2/4] Waiting for services to be ready...
timeout /t 5 /nobreak >nul

echo.
echo [3/4] Configuring Product Service for full stack...
cd services\product-service

REM Copy local config
if exist .env.local (
    copy /Y .env.local .env >nul
    echo Created .env from .env.local
) else (
    echo DB_HOST=localhost > .env
    echo DB_PORT=5432 >> .env
    echo DB_NAME=products_db >> .env
    echo REDIS_HOST=localhost >> .env
    echo RABBITMQ_HOST=localhost >> .env
    echo MOCK_MODE=false >> .env
    echo Created .env with default values
)

echo.
echo [4/4] Starting Product Service...
echo.
echo Service will connect to:
echo   - PostgreSQL: localhost:5432
echo   - Redis: localhost:6379
echo   - RabbitMQ: localhost:5672
echo.
echo Management UIs:
echo   - RabbitMQ: http://localhost:15672 (guest/guest)
echo.
echo Press Ctrl+C to stop the service
echo ========================================
echo.

REM Activate venv and run
call venv\Scripts\activate.bat
python -m uvicorn app.main:app --reload --port 8081
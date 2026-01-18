@echo off
REM Check Podman infrastructure status
REM Run from: C:\mygit\e-com-site

echo ========================================
echo Infrastructure Status
echo ========================================
echo.

echo Running Containers:
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo All Containers (including stopped):
podman ps -a --format "table {{.Names}}\t{{.Status}}"

echo.
echo Volumes:
podman volume ls

echo.
echo Networks:
podman network ls

echo.

REM Test connectivity
echo Testing Services:
echo.

podman exec postgres-local pg_isready -U postgres >nul 2>&1
if errorlevel 1 (
    echo   PostgreSQL: NOT READY
) else (
    echo   PostgreSQL: READY
)

podman exec redis-local redis-cli ping >nul 2>&1
if errorlevel 1 (
    echo   Redis: NOT READY
) else (
    echo   Redis: READY
)

podman exec rabbitmq-local rabbitmq-diagnostics ping >nul 2>&1
if errorlevel 1 (
    echo   RabbitMQ: NOT READY
) else (
    echo   RabbitMQ: READY
)

echo.
pause
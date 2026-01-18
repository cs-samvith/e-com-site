@echo off
REM Stop infrastructure with Podman
REM Run from: C:\mygit\e-com-site

echo ========================================
echo Stopping Infrastructure
echo ========================================
echo.

echo Stopping containers...
podman stop postgres-local redis-local rabbitmq-local 2>nul

echo.
echo Containers stopped.
echo.
echo To remove containers (clean slate):
echo   podman rm postgres-local redis-local rabbitmq-local
echo.
echo To remove volumes (delete all data):
echo   podman volume rm postgres_data redis_data rabbitmq_data
echo.
pause
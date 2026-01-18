@echo off
echo ========================================
echo User Service with Infrastructure
echo ========================================
echo.

set DB_HOST=localhost
set DB_NAME=users_db
set REDIS_HOST=localhost
set RABBITMQ_HOST=localhost
set MOCK_MODE=false

call venv\Scripts\activate.bat
python -m uvicorn app.main:app --reload --port 8080